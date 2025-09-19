;; Attendgov - Hospital Registry Contract
;; Government healthcare facility management and verification system

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u301))
(define-constant ERR-HOSPITAL-NOT-FOUND (err u302))
(define-constant ERR-HOSPITAL-EXISTS (err u303))
(define-constant ERR-INVALID-LICENSE (err u304))
(define-constant ERR-CAPACITY-EXCEEDED (err u305))
(define-constant ERR-INVALID-PARAMETERS (err u306))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-HOSPITALS u200)
(define-constant MAX-CAPACITY u10000)
(define-constant MIN-STAFF-RATIO u10) ;; 1 staff per 10 patients

;; Hospital type constants
(define-constant HOSPITAL-PUBLIC u1)
(define-constant HOSPITAL-PRIVATE u2)
(define-constant HOSPITAL-SPECIALIST u3)
(define-constant HOSPITAL-EMERGENCY u4)

;; Hospital status constants
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-SUSPENDED u2)
(define-constant STATUS-MAINTENANCE u3)
(define-constant STATUS-CLOSED u4)

;; Data variables
(define-data-var total-hospitals uint u0)
(define-data-var system-initialized bool false)
(define-data-var total-capacity uint u0)

;; Hospital information map
(define-map hospitals
  uint ;; hospital-id
  {
    name: (string-ascii 128),
    license-number: (string-ascii 32),
    hospital-type: uint,
    location: (string-ascii 128),
    capacity: uint,
    current-patients: uint,
    staff-count: uint,
    administrator: principal,
    registration-block: uint,
    last-inspection: uint,
    status: uint,
    specializations: (list 10 (string-ascii 32)),
    contact-info: (string-ascii 256)
  }
)

;; Hospital services and capabilities
(define-map hospital-services
  uint ;; hospital-id
  {
    emergency-services: bool,
    surgery-facilities: bool,
    icu-beds: uint,
    maternity-ward: bool,
    pediatric-care: bool,
    mental-health: bool,
    radiology: bool,
    laboratory: bool,
    pharmacy: bool,
    ambulance-service: bool
  }
)

;; Hospital performance metrics
(define-map hospital-performance
  uint ;; hospital-id
  {
    average-wait-time: uint,
    patient-satisfaction: uint,
    mortality-rate: uint,
    readmission-rate: uint,
    staff-turnover: uint,
    equipment-uptime: uint,
    compliance-score: uint,
    last-updated: uint
  }
)

;; Hospital licensing and compliance
(define-map hospital-licenses
  uint ;; hospital-id
  {
    medical-license: bool,
    fire-safety: bool,
    health-department: bool,
    building-permits: bool,
    waste-management: bool,
    medical-waste: bool,
    expiry-date: uint,
    renewal-due: uint
  }
)

;; Administrative permissions
(define-map registry-admins
  principal
  {
    can-register: bool,
    can-inspect: bool,
    can-suspend: bool,
    permission-level: uint
  }
)

;; Hospital location index
(define-map location-hospitals
  (string-ascii 64) ;; region/city
  (list 50 uint) ;; hospital IDs in this location
)

;; Initialize contract owner with admin permissions
(map-set registry-admins CONTRACT-OWNER
  {
    can-register: true,
    can-inspect: true,
    can-suspend: true,
    permission-level: u5
  }
)

;; Private helper functions

;; Check if user has admin permission
(define-private (is-admin (user principal))
  (match (map-get? registry-admins user)
    admin (get can-register admin)
    false
  )
)

;; Check if hospital exists
(define-private (hospital-exists (hospital-id uint))
  (is-some (map-get? hospitals hospital-id))
)

;; Calculate hospital utilization rate
(define-private (calculate-utilization (current-patients uint) (capacity uint))
  (if (> capacity u0)
    (/ (* current-patients u100) capacity)
    u0
  )
)

;; Check if hospital has adequate staffing
(define-private (has-adequate-staff (staff-count uint) (current-patients uint))
  (>= (* staff-count MIN-STAFF-RATIO) current-patients)
)

;; Update location index
(define-private (update-location-index (location (string-ascii 64)) (hospital-id uint))
  (match (map-get? location-hospitals location)
    existing-list
      (if (< (len existing-list) u50)
        (map-set location-hospitals location (unwrap-panic (as-max-len? (append existing-list hospital-id) u50)))
        false
      )
    (map-set location-hospitals location (list hospital-id))
  )
)

;; Public functions

;; Register a new hospital
(define-public (register-hospital
  (name (string-ascii 128))
  (license-number (string-ascii 32))
  (hospital-type uint)
  (location (string-ascii 128))
  (capacity uint)
  (administrator principal)
  (specializations (list 10 (string-ascii 32)))
  (contact-info (string-ascii 256))
)
  (let (
    (hospital-id (+ (var-get total-hospitals) u1))
    (location-key (unwrap-panic (as-max-len? location u64)))
  )
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (< (var-get total-hospitals) MAX-HOSPITALS) ERR-CAPACITY-EXCEEDED)
    (asserts! (<= capacity MAX-CAPACITY) ERR-INVALID-PARAMETERS)
    (asserts! (<= hospital-type HOSPITAL-EMERGENCY) ERR-INVALID-PARAMETERS)
    
    (map-set hospitals hospital-id
      {
        name: name,
        license-number: license-number,
        hospital-type: hospital-type,
        location: location,
        capacity: capacity,
        current-patients: u0,
        staff-count: u0,
        administrator: administrator,
        registration-block: stacks-block-height,
        last-inspection: u0,
        status: STATUS-ACTIVE,
        specializations: specializations,
        contact-info: contact-info
      }
    )
    
    ;; Initialize hospital services
    (map-set hospital-services hospital-id
      {
        emergency-services: false,
        surgery-facilities: false,
        icu-beds: u0,
        maternity-ward: false,
        pediatric-care: false,
        mental-health: false,
        radiology: false,
        laboratory: false,
        pharmacy: false,
        ambulance-service: false
      }
    )
    
    ;; Update location index
    (update-location-index location-key hospital-id)
    
    (var-set total-hospitals hospital-id)
    (var-set total-capacity (+ (var-get total-capacity) capacity))
    (ok hospital-id)
  )
)

;; Update hospital services and capabilities
(define-public (update-hospital-services
  (hospital-id uint)
  (emergency-services bool)
  (surgery-facilities bool)
  (icu-beds uint)
  (maternity-ward bool)
  (pediatric-care bool)
  (mental-health bool)
  (radiology bool)
  (laboratory bool)
  (pharmacy bool)
  (ambulance-service bool)
)
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (hospital-exists hospital-id) ERR-HOSPITAL-NOT-FOUND)
    
    (map-set hospital-services hospital-id
      {
        emergency-services: emergency-services,
        surgery-facilities: surgery-facilities,
        icu-beds: icu-beds,
        maternity-ward: maternity-ward,
        pediatric-care: pediatric-care,
        mental-health: mental-health,
        radiology: radiology,
        laboratory: laboratory,
        pharmacy: pharmacy,
        ambulance-service: ambulance-service
      }
    )
    
    (ok true)
  )
)

;; Update hospital patient count
(define-public (update-patient-count (hospital-id uint) (new-patient-count uint))
  (let (
    (hospital-info (unwrap! (map-get? hospitals hospital-id) ERR-HOSPITAL-NOT-FOUND))
  )
    (asserts! 
      (or (is-admin tx-sender) (is-eq tx-sender (get administrator hospital-info)))
      ERR-UNAUTHORIZED
    )
    (asserts! (<= new-patient-count (get capacity hospital-info)) ERR-CAPACITY-EXCEEDED)
    
    (map-set hospitals hospital-id
      (merge hospital-info { current-patients: new-patient-count })
    )
    
    (ok true)
  )
)

;; Update hospital performance metrics
(define-public (update-performance-metrics
  (hospital-id uint)
  (average-wait-time uint)
  (patient-satisfaction uint)
  (mortality-rate uint)
  (readmission-rate uint)
  (staff-turnover uint)
  (equipment-uptime uint)
  (compliance-score uint)
)
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (hospital-exists hospital-id) ERR-HOSPITAL-NOT-FOUND)
    (asserts! (<= patient-satisfaction u100) ERR-INVALID-PARAMETERS)
    (asserts! (<= equipment-uptime u100) ERR-INVALID-PARAMETERS)
    (asserts! (<= compliance-score u100) ERR-INVALID-PARAMETERS)
    
    (map-set hospital-performance hospital-id
      {
        average-wait-time: average-wait-time,
        patient-satisfaction: patient-satisfaction,
        mortality-rate: mortality-rate,
        readmission-rate: readmission-rate,
        staff-turnover: staff-turnover,
        equipment-uptime: equipment-uptime,
        compliance-score: compliance-score,
        last-updated: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Update hospital status
(define-public (update-hospital-status (hospital-id uint) (new-status uint))
  (let (
    (hospital-info (unwrap! (map-get? hospitals hospital-id) ERR-HOSPITAL-NOT-FOUND))
  )
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (<= new-status STATUS-CLOSED) ERR-INVALID-PARAMETERS)
    
    (map-set hospitals hospital-id
      (merge hospital-info 
        { 
          status: new-status,
          last-inspection: stacks-block-height
        }
      )
    )
    
    (ok true)
  )
)

;; Conduct hospital inspection
(define-public (conduct-inspection
  (hospital-id uint)
  (medical-license bool)
  (fire-safety bool)
  (health-department bool)
  (building-permits bool)
  (waste-management bool)
  (medical-waste bool)
  (expiry-date uint)
)
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (hospital-exists hospital-id) ERR-HOSPITAL-NOT-FOUND)
    
    (map-set hospital-licenses hospital-id
      {
        medical-license: medical-license,
        fire-safety: fire-safety,
        health-department: health-department,
        building-permits: building-permits,
        waste-management: waste-management,
        medical-waste: medical-waste,
        expiry-date: expiry-date,
        renewal-due: (+ expiry-date u525600) ;; One year in blocks
      }
    )
    
    ;; Update last inspection date
    (let (
      (hospital-info (unwrap! (map-get? hospitals hospital-id) ERR-HOSPITAL-NOT-FOUND))
    )
      (map-set hospitals hospital-id
        (merge hospital-info { last-inspection: stacks-block-height })
      )
    )
    
    (ok true)
  )
)

;; Grant admin permissions
(define-public (grant-admin-permissions
  (user principal)
  (can-register bool)
  (can-inspect bool)
  (can-suspend bool)
  (level uint)
)
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    
    (map-set registry-admins user
      {
        can-register: can-register,
        can-inspect: can-inspect,
        can-suspend: can-suspend,
        permission-level: level
      }
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get hospital information
(define-read-only (get-hospital-info (hospital-id uint))
  (map-get? hospitals hospital-id)
)

;; Get hospital services
(define-read-only (get-hospital-services (hospital-id uint))
  (map-get? hospital-services hospital-id)
)

;; Get hospital performance
(define-read-only (get-hospital-performance (hospital-id uint))
  (map-get? hospital-performance hospital-id)
)

;; Get hospital licenses
(define-read-only (get-hospital-licenses (hospital-id uint))
  (map-get? hospital-licenses hospital-id)
)

;; Get hospitals in location
(define-read-only (get-hospitals-by-location (location (string-ascii 64)))
  (default-to (list) (map-get? location-hospitals location))
)

;; Get system overview
(define-read-only (get-system-overview)
  {
    total-hospitals: (var-get total-hospitals),
    total-capacity: (var-get total-capacity),
    system-initialized: (var-get system-initialized)
  }
)

;; Calculate hospital utilization
(define-read-only (get-hospital-utilization (hospital-id uint))
  (match (map-get? hospitals hospital-id)
    hospital-info
      (some (calculate-utilization 
        (get current-patients hospital-info) 
        (get capacity hospital-info)
      ))
    none
  )
)

;; Check if hospital meets staffing requirements
(define-read-only (check-staffing-adequacy (hospital-id uint))
  (match (map-get? hospitals hospital-id)
    hospital-info
      (some (has-adequate-staff 
        (get staff-count hospital-info) 
        (get current-patients hospital-info)
      ))
    none
  )
)

;; Find hospitals by type
(define-read-only (get-hospitals-by-type (hospital-type uint))
  ;; This would require iteration in a real implementation
  ;; For now, return empty list as placeholder
  (list)
)

;; Initialize system
(define-public (initialize-system)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (not (var-get system-initialized)) ERR-INVALID-PARAMETERS)
    
    (var-set system-initialized true)
    (ok true)
  )
)

