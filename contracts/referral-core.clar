;; Attendgov - Referral Core Contract
;; Patient referral and care coordination system for government healthcare facilities

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-REFERRAL-NOT-FOUND (err u402))
(define-constant ERR-INVALID-HOSPITAL (err u403))
(define-constant ERR-HOSPITAL-CAPACITY (err u404))
(define-constant ERR-REFERRAL-EXPIRED (err u405))
(define-constant ERR-INVALID-STATUS (err u406))
(define-constant ERR-ALREADY-PROCESSED (err u407))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-REFERRALS u10000)
(define-constant REFERRAL-VALIDITY-BLOCKS u4320) ;; 3 days in blocks
(define-constant EMERGENCY-PRIORITY u1)
(define-constant HIGH-PRIORITY u2)
(define-constant NORMAL-PRIORITY u3)
(define-constant LOW-PRIORITY u4)

;; Referral status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-ACCEPTED u1)
(define-constant STATUS-REJECTED u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-CANCELLED u4)
(define-constant STATUS-EXPIRED u5)

;; Data variables
(define-data-var total-referrals uint u0)
(define-data-var processed-referrals uint u0)
(define-data-var system-initialized bool false)

;; Patient referral information
(define-map referrals
  uint ;; referral-id
  {
    patient-id: (string-ascii 32),
    patient-name: (string-ascii 128),
    patient-age: uint,
    referring-hospital: uint,
    target-hospital: uint,
    referring-doctor: principal,
    medical-condition: (string-ascii 256),
    urgency-level: uint,
    referral-reason: (string-ascii 512),
    required-specialization: (string-ascii 64),
    creation-block: uint,
    expiry-block: uint,
    status: uint,
    processing-doctor: (optional principal),
    decision-block: uint,
    decision-notes: (string-ascii 256)
  }
)

;; Medical history and patient data
(define-map patient-medical-data
  (string-ascii 32) ;; patient-id
  {
    blood-type: (string-ascii 8),
    allergies: (string-ascii 256),
    chronic-conditions: (string-ascii 256),
    current-medications: (string-ascii 256),
    emergency-contact: (string-ascii 128),
    insurance-info: (string-ascii 128),
    medical-history: (string-ascii 512),
    last-updated: uint
  }
)

;; Referral tracking and workflow
(define-map referral-workflow
  uint ;; referral-id
  {
    initial-assessment: (string-ascii 256),
    diagnostic-tests: (string-ascii 256),
    treatment-plan: (string-ascii 256),
    expected-duration: uint,
    estimated-cost: uint,
    bed-assignment: (optional uint),
    assigned-staff: (list 5 principal),
    care-team-notes: (string-ascii 512)
  }
)

;; Hospital capacity and availability
(define-map hospital-availability
  uint ;; hospital-id
  {
    available-beds: uint,
    available-icu: uint,
    available-specialists: uint,
    current-load: uint,
    accepting-referrals: bool,
    emergency-only: bool,
    last-updated: uint
  }
)

;; Doctor authorization and permissions
(define-map doctor-permissions
  principal
  {
    hospital-id: uint,
    specialization: (string-ascii 64),
    can-refer: bool,
    can-accept: bool,
    can-transfer: bool,
    license-number: (string-ascii 32),
    permission-level: uint
  }
)

;; Quality metrics and outcomes
(define-map referral-outcomes
  uint ;; referral-id
  {
    treatment-successful: bool,
    patient-satisfaction: uint,
    length-of-stay: uint,
    complications: (string-ascii 256),
    readmission-required: bool,
    outcome-notes: (string-ascii 256),
    discharge-date: uint,
    follow-up-required: bool
  }
)

;; Initialize contract owner with admin permissions
(map-set doctor-permissions CONTRACT-OWNER
  {
    hospital-id: u0,
    specialization: "administrator",
    can-refer: true,
    can-accept: true,
    can-transfer: true,
    license-number: "ADMIN001",
    permission-level: u5
  }
)

;; Private helper functions

;; Check if user is authorized doctor
(define-private (is-authorized-doctor (user principal))
  (is-some (map-get? doctor-permissions user))
)

;; Check if referral is valid (not expired)
(define-private (is-referral-valid (referral-data 
  {
    patient-id: (string-ascii 32),
    patient-name: (string-ascii 128),
    patient-age: uint,
    referring-hospital: uint,
    target-hospital: uint,
    referring-doctor: principal,
    medical-condition: (string-ascii 256),
    urgency-level: uint,
    referral-reason: (string-ascii 512),
    required-specialization: (string-ascii 64),
    creation-block: uint,
    expiry-block: uint,
    status: uint,
    processing-doctor: (optional principal),
    decision-block: uint,
    decision-notes: (string-ascii 256)
  }
))
  (< stacks-block-height (get expiry-block referral-data))
)

;; Check hospital capacity
(define-private (has-capacity (hospital-id uint) (urgency uint))
  (match (map-get? hospital-availability hospital-id)
    availability
      (and 
        (get accepting-referrals availability)
        (or 
          (not (get emergency-only availability))
          (is-eq urgency EMERGENCY-PRIORITY)
        )
        (> (get available-beds availability) u0)
      )
    false
  )
)

;; Calculate referral priority score
(define-private (calculate-priority-score (urgency uint) (age uint))
  (+ urgency (if (> age u65) u1 u0))
)

;; Update hospital capacity
(define-private (update-hospital-capacity (hospital-id uint) (beds-change int))
  (match (map-get? hospital-availability hospital-id)
    current-availability
      (let (
        (current-beds (get available-beds current-availability))
        (new-beds 
          (if (> beds-change 0)
            (+ current-beds (to-uint beds-change))
            (if (>= current-beds (to-uint (- 0 beds-change)))
              (- current-beds (to-uint (- 0 beds-change)))
              u0
            )
          )
        )
      )
        (map-set hospital-availability hospital-id
          (merge current-availability 
            {
              available-beds: new-beds,
              last-updated: stacks-block-height
            }
          )
        )
      )
    false
  )
)

;; Public functions

;; Submit patient referral
(define-public (submit-referral
  (patient-id (string-ascii 32))
  (patient-name (string-ascii 128))
  (patient-age uint)
  (target-hospital uint)
  (medical-condition (string-ascii 256))
  (urgency-level uint)
  (referral-reason (string-ascii 512))
  (required-specialization (string-ascii 64))
)
  (let (
    (referral-id (+ (var-get total-referrals) u1))
    (doctor-info (unwrap! (map-get? doctor-permissions tx-sender) ERR-UNAUTHORIZED))
    (referring-hospital (get hospital-id doctor-info))
  )
    (asserts! (get can-refer doctor-info) ERR-UNAUTHORIZED)
    (asserts! (<= urgency-level LOW-PRIORITY) ERR-INVALID-STATUS)
    (asserts! (< (var-get total-referrals) MAX-REFERRALS) ERR-HOSPITAL-CAPACITY)
    (asserts! (has-capacity target-hospital urgency-level) ERR-HOSPITAL-CAPACITY)
    
    (map-set referrals referral-id
      {
        patient-id: patient-id,
        patient-name: patient-name,
        patient-age: patient-age,
        referring-hospital: referring-hospital,
        target-hospital: target-hospital,
        referring-doctor: tx-sender,
        medical-condition: medical-condition,
        urgency-level: urgency-level,
        referral-reason: referral-reason,
        required-specialization: required-specialization,
        creation-block: stacks-block-height,
        expiry-block: (+ stacks-block-height REFERRAL-VALIDITY-BLOCKS),
        status: STATUS-PENDING,
        processing-doctor: none,
        decision-block: u0,
        decision-notes: ""
      }
    )
    
    (var-set total-referrals referral-id)
    (ok referral-id)
  )
)

;; Process referral (accept/reject)
(define-public (process-referral
  (referral-id uint)
  (accept bool)
  (decision-notes (string-ascii 256))
)
  (let (
    (referral-data (unwrap! (map-get? referrals referral-id) ERR-REFERRAL-NOT-FOUND))
    (doctor-info (unwrap! (map-get? doctor-permissions tx-sender) ERR-UNAUTHORIZED))
  )
    (asserts! (get can-accept doctor-info) ERR-UNAUTHORIZED)
    (asserts! 
      (is-eq (get target-hospital referral-data) (get hospital-id doctor-info))
      ERR-UNAUTHORIZED
    )
    (asserts! (is-eq (get status referral-data) STATUS-PENDING) ERR-ALREADY-PROCESSED)
    (asserts! (is-referral-valid referral-data) ERR-REFERRAL-EXPIRED)
    
    ;; Update referral status
    (map-set referrals referral-id
      (merge referral-data
        {
          status: (if accept STATUS-ACCEPTED STATUS-REJECTED),
          processing-doctor: (some tx-sender),
          decision-block: stacks-block-height,
          decision-notes: decision-notes
        }
      )
    )
    
    ;; Update hospital capacity if accepted
    (if accept
      (update-hospital-capacity (get target-hospital referral-data) -1)
      true
    )
    
    (var-set processed-referrals (+ (var-get processed-referrals) u1))
    (ok accept)
  )
)

;; Update patient medical data
(define-public (update-patient-medical-data
  (patient-id (string-ascii 32))
  (blood-type (string-ascii 8))
  (allergies (string-ascii 256))
  (chronic-conditions (string-ascii 256))
  (current-medications (string-ascii 256))
  (emergency-contact (string-ascii 128))
  (insurance-info (string-ascii 128))
  (medical-history (string-ascii 512))
)
  (begin
    (asserts! (is-authorized-doctor tx-sender) ERR-UNAUTHORIZED)
    
    (map-set patient-medical-data patient-id
      {
        blood-type: blood-type,
        allergies: allergies,
        chronic-conditions: chronic-conditions,
        current-medications: current-medications,
        emergency-contact: emergency-contact,
        insurance-info: insurance-info,
        medical-history: medical-history,
        last-updated: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Complete referral with outcome
(define-public (complete-referral
  (referral-id uint)
  (treatment-successful bool)
  (patient-satisfaction uint)
  (length-of-stay uint)
  (complications (string-ascii 256))
  (outcome-notes (string-ascii 256))
  (follow-up-required bool)
)
  (let (
    (referral-data (unwrap! (map-get? referrals referral-id) ERR-REFERRAL-NOT-FOUND))
    (doctor-info (unwrap! (map-get? doctor-permissions tx-sender) ERR-UNAUTHORIZED))
  )
    (asserts! 
      (is-eq (get target-hospital referral-data) (get hospital-id doctor-info))
      ERR-UNAUTHORIZED
    )
    (asserts! (is-eq (get status referral-data) STATUS-ACCEPTED) ERR-INVALID-STATUS)
    (asserts! (<= patient-satisfaction u100) ERR-INVALID-STATUS)
    
    ;; Update referral status to completed
    (map-set referrals referral-id
      (merge referral-data { status: STATUS-COMPLETED })
    )
    
    ;; Record outcome data
    (map-set referral-outcomes referral-id
      {
        treatment-successful: treatment-successful,
        patient-satisfaction: patient-satisfaction,
        length-of-stay: length-of-stay,
        complications: complications,
        readmission-required: false,
        outcome-notes: outcome-notes,
        discharge-date: stacks-block-height,
        follow-up-required: follow-up-required
      }
    )
    
    ;; Free up hospital capacity
    (update-hospital-capacity (get target-hospital referral-data) 1)
    
    (ok true)
  )
)

;; Update hospital availability
(define-public (update-hospital-availability
  (hospital-id uint)
  (available-beds uint)
  (available-icu uint)
  (available-specialists uint)
  (accepting-referrals bool)
  (emergency-only bool)
)
  (begin
    (asserts! (is-authorized-doctor tx-sender) ERR-UNAUTHORIZED)
    
    (map-set hospital-availability hospital-id
      {
        available-beds: available-beds,
        available-icu: available-icu,
        available-specialists: available-specialists,
        current-load: u0,
        accepting-referrals: accepting-referrals,
        emergency-only: emergency-only,
        last-updated: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Grant doctor permissions
(define-public (grant-doctor-permissions
  (doctor principal)
  (hospital-id uint)
  (specialization (string-ascii 64))
  (license-number (string-ascii 32))
  (can-refer bool)
  (can-accept bool)
  (can-transfer bool)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (map-set doctor-permissions doctor
      {
        hospital-id: hospital-id,
        specialization: specialization,
        can-refer: can-refer,
        can-accept: can-accept,
        can-transfer: can-transfer,
        license-number: license-number,
        permission-level: u3
      }
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get referral information
(define-read-only (get-referral-info (referral-id uint))
  (map-get? referrals referral-id)
)

;; Get patient medical data
(define-read-only (get-patient-medical-data (patient-id (string-ascii 32)))
  (map-get? patient-medical-data patient-id)
)

;; Get hospital availability
(define-read-only (get-hospital-availability (hospital-id uint))
  (map-get? hospital-availability hospital-id)
)

;; Get referral outcome
(define-read-only (get-referral-outcome (referral-id uint))
  (map-get? referral-outcomes referral-id)
)

;; Get doctor permissions
(define-read-only (get-doctor-permissions (doctor principal))
  (map-get? doctor-permissions doctor)
)

;; Get system statistics
(define-read-only (get-system-stats)
  {
    total-referrals: (var-get total-referrals),
    processed-referrals: (var-get processed-referrals),
    pending-referrals: (- (var-get total-referrals) (var-get processed-referrals)),
    system-initialized: (var-get system-initialized)
  }
)

;; Check if referral is still valid
(define-read-only (check-referral-validity (referral-id uint))
  (match (map-get? referrals referral-id)
    referral-data (some (is-referral-valid referral-data))
    none
  )
)

;; Get referrals by hospital
(define-read-only (get-referrals-by-hospital (hospital-id uint))
  ;; This would require iteration in a real implementation
  ;; For now, return empty list as placeholder
  (list)
)

;; Initialize system
(define-public (initialize-system)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (not (var-get system-initialized)) ERR-ALREADY-PROCESSED)
    
    (var-set system-initialized true)
    (ok true)
  )
)

