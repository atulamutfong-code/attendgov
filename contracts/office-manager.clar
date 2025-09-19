;; Attendgov - Office Manager Contract
;; Administrative functions for managing officials and government office operations

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u201))
(define-constant ERR-DEPARTMENT-NOT-FOUND (err u202))
(define-constant ERR-DEPARTMENT-EXISTS (err u203))
(define-constant ERR-INVALID-PARAMETERS (err u204))
(define-constant ERR-LEAVE-NOT-FOUND (err u205))
(define-constant ERR-ALREADY-APPROVED (err u206))
(define-constant ERR-INVALID-DATE (err u207))
(define-constant ERR-INSUFFICIENT-BALANCE (err u208))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-DEPARTMENTS u50)
(define-constant MAX-OFFICIALS-PER-DEPT u100)
(define-constant MAX-LEAVE-DAYS u30)
(define-constant ANNUAL-LEAVE-BALANCE u20) ;; 20 days per year
(define-constant BLOCKS-PER-DAY u1440) ;; Approximately 1440 blocks per day

;; Leave type constants
(define-constant LEAVE-SICK u1)
(define-constant LEAVE-VACATION u2)
(define-constant LEAVE-EMERGENCY u3)
(define-constant LEAVE-OFFICIAL u4)

;; Leave status constants
(define-constant LEAVE-PENDING u0)
(define-constant LEAVE-APPROVED u1)
(define-constant LEAVE-REJECTED u2)
(define-constant LEAVE-CANCELLED u3)

;; Role hierarchy constants
(define-constant ROLE-JUNIOR u1)
(define-constant ROLE-SENIOR u2)
(define-constant ROLE-SUPERVISOR u3)
(define-constant ROLE-MANAGER u4)
(define-constant ROLE-DIRECTOR u5)

;; Data variables
(define-data-var total-departments uint u0)
(define-data-var total-leave-requests uint u0)
(define-data-var system-initialized bool false)
(define-data-var current-year uint u2024)

;; Department information map
(define-map departments
  (string-ascii 32) ;; department-id
  {
    department-name: (string-ascii 64),
    head-of-department: principal,
    total-officials: uint,
    active-officials: uint,
    budget-allocation: uint,
    creation-block: uint,
    last-updated: uint,
    status: uint
  }
)

;; Official roles and hierarchies
(define-map official-roles
  principal
  {
    department: (string-ascii 32),
    position-title: (string-ascii 64),
    role-level: uint,
    supervisor: (optional principal),
    subordinates: uint,
    annual-leave-balance: uint,
    sick-leave-balance: uint,
    salary-grade: uint,
    hire-date: uint
  }
)

;; Leave requests and management
(define-map leave-requests
  uint ;; request-id
  {
    requesting-official: principal,
    leave-type: uint,
    start-date: uint,
    end-date: uint,
    days-requested: uint,
    reason: (string-ascii 256),
    status: uint,
    approving-authority: (optional principal),
    submission-block: uint,
    decision-block: uint,
    decision-notes: (string-ascii 256)
  }
)

;; Performance tracking
(define-map official-performance
  principal
  {
    attendance-score: uint,
    punctuality-score: uint,
    duty-completion-rate: uint,
    total-evaluations: uint,
    last-evaluation: uint,
    commendations: uint,
    warnings: uint,
    overall-rating: uint
  }
)

;; Meeting and event scheduling
(define-map scheduled-meetings
  uint ;; meeting-id
  {
    meeting-title: (string-ascii 128),
    organizer: principal,
    department: (string-ascii 32),
    scheduled-date: uint,
    duration-hours: uint,
    location: (string-ascii 64),
    required-attendees: uint,
    actual-attendees: uint,
    meeting-type: uint,
    status: uint
  }
)

;; Public reporting and transparency
(define-map public-reports
  uint ;; report-id
  {
    report-type: uint,
    department: (string-ascii 32),
    reporting-period: uint,
    total-officials: uint,
    average-attendance: uint,
    completed-duties: uint,
    pending-duties: uint,
    published-block: uint,
    published-by: principal
  }
)

;; Administrative permissions
(define-map admin-permissions
  principal
  { 
    can-manage-departments: bool,
    can-approve-leave: bool,
    can-assign-duties: bool,
    can-generate-reports: bool,
    permission-level: uint
  }
)

;; Initialize contract owner with full permissions
(map-set admin-permissions CONTRACT-OWNER
  {
    can-manage-departments: true,
    can-approve-leave: true,
    can-assign-duties: true,
    can-generate-reports: true,
    permission-level: u5
  }
)

;; Private helper functions

;; Check if user has specific admin permission
(define-private (has-permission (user principal) (permission-type (string-ascii 32)))
  (match (map-get? admin-permissions user)
    permissions 
      (if (is-eq permission-type "departments")
        (get can-manage-departments permissions)
        (if (is-eq permission-type "leave")
          (get can-approve-leave permissions)
          (if (is-eq permission-type "duties")
            (get can-assign-duties permissions)
            (get can-generate-reports permissions)
          )
        )
      )
    false
  )
)

;; Check if department exists
(define-private (department-exists (dept-id (string-ascii 32)))
  (is-some (map-get? departments dept-id))
)

;; Calculate leave days between two dates
(define-private (calculate-leave-days (start-date uint) (end-date uint))
  (/ (- end-date start-date) BLOCKS-PER-DAY)
)

;; Check if user is authorized to approve leave for official
(define-private (can-approve-leave-for (approver principal) (official principal))
  (match (map-get? official-roles official)
    official-data
      (match (get supervisor official-data)
        supervisor (is-eq approver supervisor)
        false
      )
    false
  )
)

;; Update department statistics
(define-private (update-department-stats (dept-id (string-ascii 32)) (action uint))
  (match (map-get? departments dept-id)
    dept-data
      (map-set departments dept-id
        (merge dept-data
          {
            active-officials: 
              (if (is-eq action u1) ;; adding official
                (+ (get active-officials dept-data) u1)
                (- (get active-officials dept-data) u1) ;; removing official
              ),
            last-updated: stacks-block-height
          }
        )
      )
    false
  )
)

;; Public functions

;; Create a new government department
(define-public (create-department
  (dept-id (string-ascii 32))
  (dept-name (string-ascii 64))
  (head-of-dept principal)
  (budget-allocation uint)
)
  (begin
    (asserts! (has-permission tx-sender "departments") ERR-UNAUTHORIZED)
    (asserts! (not (department-exists dept-id)) ERR-DEPARTMENT-EXISTS)
    (asserts! (< (var-get total-departments) MAX-DEPARTMENTS) ERR-INVALID-PARAMETERS)
    
    (map-set departments dept-id
      {
        department-name: dept-name,
        head-of-department: head-of-dept,
        total-officials: u0,
        active-officials: u0,
        budget-allocation: budget-allocation,
        creation-block: stacks-block-height,
        last-updated: stacks-block-height,
        status: u1
      }
    )
    
    (var-set total-departments (+ (var-get total-departments) u1))
    (ok true)
  )
)

;; Assign role and hierarchy to official
(define-public (assign-official-role
  (official principal)
  (department (string-ascii 32))
  (position-title (string-ascii 64))
  (role-level uint)
  (supervisor (optional principal))
  (salary-grade uint)
)
  (begin
    (asserts! (has-permission tx-sender "departments") ERR-UNAUTHORIZED)
    (asserts! (department-exists department) ERR-DEPARTMENT-NOT-FOUND)
    (asserts! (<= role-level ROLE-DIRECTOR) ERR-INVALID-PARAMETERS)
    
    (map-set official-roles official
      {
        department: department,
        position-title: position-title,
        role-level: role-level,
        supervisor: supervisor,
        subordinates: u0,
        annual-leave-balance: ANNUAL-LEAVE-BALANCE,
        sick-leave-balance: u10,
        salary-grade: salary-grade,
        hire-date: stacks-block-height
      }
    )
    
    (update-department-stats department u1)
    (ok true)
  )
)

;; Submit leave request
(define-public (submit-leave-request
  (leave-type uint)
  (start-date uint)
  (end-date uint)
  (reason (string-ascii 256))
)
  (let (
    (request-id (+ (var-get total-leave-requests) u1))
    (days-requested (calculate-leave-days start-date end-date))
    (official-info (unwrap! (map-get? official-roles tx-sender) ERR-UNAUTHORIZED))
  )
    (asserts! (> end-date start-date) ERR-INVALID-DATE)
    (asserts! (<= days-requested MAX-LEAVE-DAYS) ERR-INVALID-PARAMETERS)
    
    ;; Check leave balance based on type
    (asserts! 
      (if (is-eq leave-type LEAVE-VACATION)
        (>= (get annual-leave-balance official-info) days-requested)
        (>= (get sick-leave-balance official-info) days-requested)
      )
      ERR-INSUFFICIENT-BALANCE
    )
    
    (map-set leave-requests request-id
      {
        requesting-official: tx-sender,
        leave-type: leave-type,
        start-date: start-date,
        end-date: end-date,
        days-requested: days-requested,
        reason: reason,
        status: LEAVE-PENDING,
        approving-authority: none,
        submission-block: stacks-block-height,
        decision-block: u0,
        decision-notes: ""
      }
    )
    
    (var-set total-leave-requests request-id)
    (ok request-id)
  )
)

;; Approve or reject leave request
(define-public (process-leave-request
  (request-id uint)
  (approve bool)
  (decision-notes (string-ascii 256))
)
  (let (
    (leave-request (unwrap! (map-get? leave-requests request-id) ERR-LEAVE-NOT-FOUND))
    (requesting-official (get requesting-official leave-request))
  )
    (asserts! (can-approve-leave-for tx-sender requesting-official) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status leave-request) LEAVE-PENDING) ERR-ALREADY-APPROVED)
    
    (map-set leave-requests request-id
      (merge leave-request
        {
          status: (if approve LEAVE-APPROVED LEAVE-REJECTED),
          approving-authority: (some tx-sender),
          decision-block: stacks-block-height,
          decision-notes: decision-notes
        }
      )
    )
    
    ;; If approved, deduct from leave balance
    (if approve
      (match (map-get? official-roles requesting-official)
        official-data
          (map-set official-roles requesting-official
            (merge official-data
              {
                annual-leave-balance: 
                  (if (is-eq (get leave-type leave-request) LEAVE-VACATION)
                    (- (get annual-leave-balance official-data) (get days-requested leave-request))
                    (get annual-leave-balance official-data)
                  ),
                sick-leave-balance:
                  (if (is-eq (get leave-type leave-request) LEAVE-SICK)
                    (- (get sick-leave-balance official-data) (get days-requested leave-request))
                    (get sick-leave-balance official-data)
                  )
              }
            )
          )
        false
      )
      true
    )
    
    (ok approve)
  )
)

;; Schedule official meeting
(define-public (schedule-meeting
  (meeting-title (string-ascii 128))
  (department (string-ascii 32))
  (scheduled-date uint)
  (duration-hours uint)
  (location (string-ascii 64))
  (required-attendees uint)
)
  (let (
    (meeting-id (+ (var-get total-departments) stacks-block-height)) ;; Simple ID generation
  )
    (asserts! (has-permission tx-sender "duties") ERR-UNAUTHORIZED)
    (asserts! (department-exists department) ERR-DEPARTMENT-NOT-FOUND)
    (asserts! (> scheduled-date stacks-block-height) ERR-INVALID-DATE)
    
    (map-set scheduled-meetings meeting-id
      {
        meeting-title: meeting-title,
        organizer: tx-sender,
        department: department,
        scheduled-date: scheduled-date,
        duration-hours: duration-hours,
        location: location,
        required-attendees: required-attendees,
        actual-attendees: u0,
        meeting-type: u1,
        status: u0
      }
    )
    
    (ok meeting-id)
  )
)

;; Generate public transparency report
(define-public (generate-public-report
  (report-type uint)
  (department (string-ascii 32))
  (reporting-period uint)
)
  (let (
    (report-id (+ (var-get total-leave-requests) stacks-block-height))
    (dept-info (unwrap! (map-get? departments department) ERR-DEPARTMENT-NOT-FOUND))
  )
    (asserts! (has-permission tx-sender "reports") ERR-UNAUTHORIZED)
    
    (map-set public-reports report-id
      {
        report-type: report-type,
        department: department,
        reporting-period: reporting-period,
        total-officials: (get total-officials dept-info),
        average-attendance: u85, ;; Placeholder calculation
        completed-duties: u150, ;; Placeholder calculation
        pending-duties: u25, ;; Placeholder calculation
        published-block: stacks-block-height,
        published-by: tx-sender
      }
    )
    
    (ok report-id)
  )
)

;; Read-only functions for transparency and public access

;; Get department information
(define-read-only (get-department-info (dept-id (string-ascii 32)))
  (map-get? departments dept-id)
)

;; Get official role information
(define-read-only (get-official-role (official principal))
  (map-get? official-roles official)
)

;; Get leave request details
(define-read-only (get-leave-request (request-id uint))
  (map-get? leave-requests request-id)
)

;; Get official performance data
(define-read-only (get-performance-data (official principal))
  (map-get? official-performance official)
)

;; Get meeting information
(define-read-only (get-meeting-info (meeting-id uint))
  (map-get? scheduled-meetings meeting-id)
)

;; Get public report
(define-read-only (get-public-report (report-id uint))
  (map-get? public-reports report-id)
)

;; Get system statistics
(define-read-only (get-system-overview)
  {
    total-departments: (var-get total-departments),
    total-leave-requests: (var-get total-leave-requests),
    system-initialized: (var-get system-initialized),
    current-year: (var-get current-year)
  }
)

;; Administrative functions

;; Grant administrative permissions
(define-public (grant-admin-permissions
  (user principal)
  (manage-departments bool)
  (approve-leave bool)
  (assign-duties bool)
  (generate-reports bool)
  (level uint)
)
  (begin
    (asserts! (has-permission tx-sender "departments") ERR-UNAUTHORIZED)
    
    (map-set admin-permissions user
      {
        can-manage-departments: manage-departments,
        can-approve-leave: approve-leave,
        can-assign-duties: assign-duties,
        can-generate-reports: generate-reports,
        permission-level: level
      }
    )
    
    (ok true)
  )
)

;; Initialize system settings
(define-public (initialize-system (year uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (not (var-get system-initialized)) ERR-ALREADY-APPROVED)
    
    (var-set current-year year)
    (var-set system-initialized true)
    (ok true)
  )
)
