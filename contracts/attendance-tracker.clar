;; Attendgov - Public Office Attendance Tracker
;; Core attendance recording and verification system for government transparency

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-OFFICIAL-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-CHECKED-IN (err u103))
(define-constant ERR-NOT-CHECKED-IN (err u104))
(define-constant ERR-DUTY-NOT-FOUND (err u105))
(define-constant ERR-INVALID-STATUS (err u106))
(define-constant ERR-INVALID-TIME (err u107))
(define-constant ERR-DUPLICATE-DUTY (err u108))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-DUTY-HOURS u12) ;; Maximum 12-hour duty period
(define-constant MIN-DUTY-HOURS u1) ;; Minimum 1-hour duty period
(define-constant BLOCKS-PER-HOUR u144) ;; Approximately 144 blocks per hour

;; Status constants
(define-constant STATUS-OFF-DUTY u0)
(define-constant STATUS-ON-DUTY u1)
(define-constant STATUS-ABSENT u2)
(define-constant STATUS-EXCUSED u3)

;; Duty type constants
(define-constant DUTY-OFFICE u1)
(define-constant DUTY-MEETING u2)
(define-constant DUTY-FIELD u3)
(define-constant DUTY-EMERGENCY u4)

;; Data variables
(define-data-var total-officials uint u0)
(define-data-var total-duties uint u0)
(define-data-var system-active bool true)
(define-data-var current-period uint u0)

;; Official information map
(define-map officials
  principal
  {
    official-id: (string-ascii 32),
    name: (string-ascii 64),
    department: (string-ascii 32),
    role: (string-ascii 32),
    current-status: uint,
    total-hours: uint,
    total-duties: uint,
    registration-block: uint,
    last-checkin: uint,
    current-duty-id: uint
  }
)

;; Duty assignments map
(define-map duty-assignments
  uint ;; duty-id
  {
    assigned-official: principal,
    duty-type: uint,
    location: (string-ascii 64),
    scheduled-start: uint,
    scheduled-end: uint,
    description: (string-ascii 128),
    created-by: principal,
    creation-block: uint,
    status: uint
  }
)

;; Attendance records map
(define-map attendance-records
  { official: principal, duty-id: uint }
  {
    checkin-time: uint,
    checkin-block: uint,
    checkout-time: uint,
    checkout-block: uint,
    actual-hours: uint,
    completion-status: uint,
    location-verified: bool,
    notes: (string-ascii 256)
  }
)

;; Daily attendance summary
(define-map daily-attendance
  { official: principal, date-block: uint }
  {
    duties-assigned: uint,
    duties-completed: uint,
    total-hours-worked: uint,
    attendance-rate: uint,
    absences: uint,
    last-updated: uint
  }
)

;; Department statistics
(define-map department-stats
  (string-ascii 32) ;; department name
  {
    total-officials: uint,
    currently-on-duty: uint,
    today-attendance-rate: uint,
    total-duties-today: uint,
    completed-duties-today: uint,
    last-updated: uint
  }
)

;; Public transparency log
(define-map public-attendance-log
  uint ;; log-id
  {
    official: principal,
    duty-id: uint,
    action: (string-ascii 16), ;; "checkin" or "checkout"
    timestamp: uint,
    block-height: uint,
    duty-type: uint,
    location: (string-ascii 64)
  }
)

;; Authorization map for administrators
(define-map admin-permissions
  principal
  bool
)

;; Initialize contract owner as admin
(map-set admin-permissions CONTRACT-OWNER true)

;; Private helper functions

;; Check if user is admin
(define-private (is-admin (user principal))
  (default-to false (map-get? admin-permissions user))
)

;; Check if official exists
(define-private (official-exists (official principal))
  (is-some (map-get? officials official))
)

;; Calculate duration in hours between blocks
(define-private (calculate-hours (start-block uint) (end-block uint))
  (/ (- end-block start-block) BLOCKS-PER-HOUR)
)

;; Calculate attendance rate as percentage
(define-private (calculate-attendance-rate (completed uint) (assigned uint))
  (if (is-eq assigned u0)
    u100
    (* (/ (* completed u100) assigned) u1)
  )
)

;; Update department statistics
(define-private (update-department-stats (department (string-ascii 32)) (action uint))
  (let (
    (current-stats (default-to 
      { total-officials: u0, currently-on-duty: u0, today-attendance-rate: u0, total-duties-today: u0, completed-duties-today: u0, last-updated: u0 }
      (map-get? department-stats department)
    ))
  )
    (map-set department-stats department
      (if (is-eq action u1) ;; checkin
        (merge current-stats { currently-on-duty: (+ (get currently-on-duty current-stats) u1), last-updated: stacks-block-height })
        (merge current-stats { currently-on-duty: (- (get currently-on-duty current-stats) u1), completed-duties-today: (+ (get completed-duties-today current-stats) u1), last-updated: stacks-block-height })
      )
    )
  )
)

;; Log public attendance action
(define-private (log-attendance-action (official principal) (duty-id uint) (action (string-ascii 16)) (duty-type uint) (location (string-ascii 64)))
  (let (
    (log-id (+ (var-get total-duties) (var-get total-officials)))
  )
    (map-set public-attendance-log log-id
      {
        official: official,
        duty-id: duty-id,
        action: action,
        timestamp: stacks-block-height,
        block-height: stacks-block-height,
        duty-type: duty-type,
        location: location
      }
    )
  )
)

;; Public functions

;; Check in for duty
(define-public (check-in (duty-id uint) (location-code (string-ascii 64)))
  (let (
    (official tx-sender)
    (duty-info (unwrap! (map-get? duty-assignments duty-id) ERR-DUTY-NOT-FOUND))
    (official-info (unwrap! (map-get? officials official) ERR-OFFICIAL-NOT-FOUND))
  )
    (asserts! (var-get system-active) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get assigned-official duty-info) official) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get current-status official-info) STATUS-OFF-DUTY) ERR-ALREADY-CHECKED-IN)
    
    ;; Create attendance record
    (map-set attendance-records { official: official, duty-id: duty-id }
      {
        checkin-time: stacks-block-height,
        checkin-block: stacks-block-height,
        checkout-time: u0,
        checkout-block: u0,
        actual-hours: u0,
        completion-status: u0,
        location-verified: true,
        notes: ""
      }
    )
    
    ;; Update official status
    (map-set officials official
      (merge official-info
        {
          current-status: STATUS-ON-DUTY,
          last-checkin: stacks-block-height,
          current-duty-id: duty-id
        }
      )
    )
    
    ;; Update department statistics
    (update-department-stats (get department official-info) u1)
    
    ;; Log public action
    (log-attendance-action official duty-id "checkin" (get duty-type duty-info) location-code)
    
    (ok true)
  )
)

;; Check out from duty
(define-public (check-out (duty-id uint) (completion-status uint) (notes (string-ascii 256)))
  (let (
    (official tx-sender)
    (official-info (unwrap! (map-get? officials official) ERR-OFFICIAL-NOT-FOUND))
    (duty-info (unwrap! (map-get? duty-assignments duty-id) ERR-DUTY-NOT-FOUND))
    (attendance-record (unwrap! (map-get? attendance-records { official: official, duty-id: duty-id }) ERR-NOT-CHECKED-IN))
  )
    (asserts! (var-get system-active) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get current-status official-info) STATUS-ON-DUTY) ERR-NOT-CHECKED-IN)
    (asserts! (is-eq (get current-duty-id official-info) duty-id) ERR-UNAUTHORIZED)
    
    (let (
      (hours-worked (calculate-hours (get checkin-block attendance-record) stacks-block-height))
    )
      ;; Update attendance record
      (map-set attendance-records { official: official, duty-id: duty-id }
        (merge attendance-record
          {
            checkout-time: stacks-block-height,
            checkout-block: stacks-block-height,
            actual-hours: hours-worked,
            completion-status: completion-status,
            notes: notes
          }
        )
      )
      
      ;; Update official status
      (map-set officials official
        (merge official-info
          {
            current-status: STATUS-OFF-DUTY,
            total-hours: (+ (get total-hours official-info) hours-worked),
            total-duties: (+ (get total-duties official-info) u1),
            current-duty-id: u0
          }
        )
      )
      
      ;; Update department statistics
      (update-department-stats (get department official-info) u2)
      
      ;; Log public action
      (log-attendance-action official duty-id "checkout" (get duty-type duty-info) (get location duty-info))
      
      (ok hours-worked)
    )
  )
)

;; Register a new government official (admin only)
(define-public (register-official 
  (official principal)
  (official-id (string-ascii 32))
  (name (string-ascii 64))
  (department (string-ascii 32))
  (role (string-ascii 32))
)
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (not (official-exists official)) ERR-DUPLICATE-DUTY)
    
    (map-set officials official
      {
        official-id: official-id,
        name: name,
        department: department,
        role: role,
        current-status: STATUS-OFF-DUTY,
        total-hours: u0,
        total-duties: u0,
        registration-block: stacks-block-height,
        last-checkin: u0,
        current-duty-id: u0
      }
    )
    
    (var-set total-officials (+ (var-get total-officials) u1))
    (ok true)
  )
)

;; Assign duty to official (admin only)
(define-public (assign-duty
  (official principal)
  (duty-type uint)
  (location (string-ascii 64))
  (scheduled-duration uint)
  (description (string-ascii 128))
)
  (let (
    (duty-id (+ (var-get total-duties) u1))
  )
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (asserts! (official-exists official) ERR-OFFICIAL-NOT-FOUND)
    (asserts! (<= scheduled-duration MAX-DUTY-HOURS) ERR-INVALID-TIME)
    (asserts! (>= scheduled-duration MIN-DUTY-HOURS) ERR-INVALID-TIME)
    
    (map-set duty-assignments duty-id
      {
        assigned-official: official,
        duty-type: duty-type,
        location: location,
        scheduled-start: stacks-block-height,
        scheduled-end: (+ stacks-block-height (* scheduled-duration BLOCKS-PER-HOUR)),
        description: description,
        created-by: tx-sender,
        creation-block: stacks-block-height,
        status: u0
      }
    )
    
    (var-set total-duties duty-id)
    (ok duty-id)
  )
)

;; Read-only functions for public transparency

;; Get official information (public)
(define-read-only (get-official-info (official principal))
  (map-get? officials official)
)

;; Get official current status (public)
(define-read-only (get-official-status (official principal))
  (match (map-get? officials official)
    official-data (ok (get current-status official-data))
    ERR-OFFICIAL-NOT-FOUND
  )
)

;; Get duty assignment details (public)
(define-read-only (get-duty-info (duty-id uint))
  (map-get? duty-assignments duty-id)
)

;; Get attendance record (public)
(define-read-only (get-attendance-record (official principal) (duty-id uint))
  (map-get? attendance-records { official: official, duty-id: duty-id })
)

;; Get department statistics (public)
(define-read-only (get-department-stats (department (string-ascii 32)))
  (map-get? department-stats department)
)

;; Get public attendance log entry
(define-read-only (get-public-log (log-id uint))
  (map-get? public-attendance-log log-id)
)

;; Get system statistics (public)
(define-read-only (get-system-stats)
  {
    total-officials: (var-get total-officials),
    total-duties: (var-get total-duties),
    system-active: (var-get system-active),
    current-period: (var-get current-period)
  }
)

;; Get daily attendance summary (public)
(define-read-only (get-daily-attendance (official principal) (date-block uint))
  (map-get? daily-attendance { official: official, date-block: date-block })
)

;; Administrative functions

;; Grant admin permissions
(define-public (grant-admin (new-admin principal))
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (map-set admin-permissions new-admin true)
    (ok true)
  )
)

;; Toggle system active state
(define-public (toggle-system-status)
  (begin
    (asserts! (is-admin tx-sender) ERR-UNAUTHORIZED)
    (var-set system-active (not (var-get system-active)))
    (ok (var-get system-active))
  )
)

