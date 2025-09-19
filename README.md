# Attendgov - Public Office Attendance Tracker 🗂️

A blockchain-based transparency system for tracking and verifying the attendance of public officials at their government duties, ensuring accountability and public trust through immutable proof of service.

## Overview

Attendgov is a decentralized attendance tracking system designed to bring transparency to government operations by providing immutable proof that public officials are showing up to their assigned duties. The system uses blockchain technology to create a tamper-proof record of official attendance, making it impossible to falsify attendance records or cover up absences.

## Features

### Core Attendance System
- **Official Registration**: Secure onboarding of government officials with identity verification
- **Real-time Check-in/Check-out**: Timestamped attendance recording with blockchain validation
- **Duty Assignment Tracking**: Monitor specific responsibilities and meeting assignments
- **Absence Management**: Transparent recording of approved and unapproved absences
- **Performance Analytics**: Calculate attendance rates and identify patterns
- **Public Transparency**: Read-only access for citizens to verify official attendance

### Administrative Controls
- **Office Management**: Department heads can manage their staff and assignments
- **Duty Scheduling**: Create and assign specific duties, meetings, and responsibilities
- **Approval Workflows**: Handle leave requests and attendance exceptions
- **Reporting System**: Generate comprehensive attendance reports for public disclosure
- **Audit Trail**: Complete immutable history of all attendance-related activities

### Healthcare System Integration
- **Hospital Registry**: Comprehensive management of government healthcare facilities
- **Patient Referral System**: Streamlined patient transfer and care coordination
- **Medical Staff Tracking**: Monitor healthcare worker attendance and availability
- **Healthcare Transparency**: Public access to hospital performance and utilization data
- **Quality Assurance**: Track patient outcomes and healthcare service delivery

## System Architecture

### Contracts
1. **attendance-tracker.clar** - Core attendance recording and verification system
2. **office-manager.clar** - Administrative functions for managing officials and duties
3. **hospital-registry.clar** - Government healthcare facility management and verification
4. **referral-core.clar** - Patient referral and care coordination system

### Key Components
- Official registration and identity management
- Real-time attendance check-in/check-out system
- Duty assignment and scheduling management
- Absence tracking and approval workflows
- Public transparency and reporting features
- Comprehensive audit trail system

## Attendance Workflow

1. **Official Registration**: Government officials register with verified credentials
2. **Duty Assignment**: Department heads assign specific duties and meeting schedules
3. **Check-in Process**: Officials check in at the start of their duty periods
4. **Duty Execution**: Real-time tracking of official presence and activities
5. **Check-out Process**: Officials check out at the end of their duty periods
6. **Performance Review**: Automatic calculation of attendance rates and compliance
7. **Public Reporting**: Transparent disclosure of attendance records to citizens

## Transparency Features

### Public Accountability
- **Open Attendance Records**: Citizens can verify when officials are on duty
- **Performance Metrics**: Public access to attendance statistics and trends
- **Real-time Status**: Live updates on which officials are currently on duty
- **Historical Data**: Complete archive of attendance patterns over time
- **Absence Tracking**: Public record of all absences and their justifications

### Government Benefits
- **Reduced Corruption**: Immutable records prevent attendance fraud
- **Improved Accountability**: Officials know their attendance is being tracked
- **Better Resource Management**: Optimize staffing based on actual attendance data
- **Public Trust**: Demonstrate commitment to transparency and good governance
- **Compliance Monitoring**: Ensure officials meet their service obligations

## Technical Specifications

### Attendance Tracking System
- Timestamp-based check-in/check-out records
- Duty assignment and scheduling management
- Absence classification (sick leave, vacation, unauthorized)
- Performance calculation and reporting
- Public transparency and access controls

### Office Management System
- Official registration and verification
- Department and role management
- Duty assignment and scheduling
- Approval workflows for leaves and exceptions
- Administrative reporting and analytics

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks blockchain development environment
- Node.js and npm for testing
- Government authorization for official registration

### Installation
```bash
git clone [repository-url]
cd attendgov
npm install
```

### Testing
```bash
clarinet check
npm test
```

### Deployment
Deploy contracts to testnet/mainnet using Clarinet deployment scripts with proper government authorization.

## Usage Examples

### Attendance Tracking System

#### Register Government Official
```clarity
(contract-call? .attendance-tracker register-official 
  "GOV001" 
  "John Smith" 
  "Health" 
  "Director")
```

#### Check In for Duty
```clarity
(contract-call? .attendance-tracker check-in 
  u1 ;; duty-id
  "BLDG-A-FL2") ;; location-code
```

#### Check Out from Duty
```clarity
(contract-call? .attendance-tracker check-out 
  u1 ;; duty-id
  u1) ;; completion-status
```

#### Check Official's Current Status
```clarity
(contract-call? .attendance-tracker get-official-status 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### Office Management System

#### Create Department
```clarity
(contract-call? .office-manager create-department
  "HEALTH"
  "Department of Health"
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  u1000000) ;; budget-allocation
```

#### Assign Official Role
```clarity
(contract-call? .office-manager assign-official-role
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  "HEALTH"
  "Chief Medical Officer"
  u4 ;; role-level
  (some 'SP1SUPERVISOR)
  u8) ;; salary-grade
```

#### Submit Leave Request
```clarity
(contract-call? .office-manager submit-leave-request
  u2 ;; leave-type (vacation)
  u1000000 ;; start-date
  u1000010 ;; end-date
  "Annual vacation")
```

### Healthcare System

#### Register Hospital
```clarity
(contract-call? .hospital-registry register-hospital
  "City General Hospital"
  "LIC123456"
  u1 ;; hospital-type (public)
  "123 Main St, City"
  u500 ;; capacity
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  (list "Cardiology" "Neurology")
  "Phone: 555-0123")
```

#### Update Hospital Services
```clarity
(contract-call? .hospital-registry update-hospital-services
  u1 ;; hospital-id
  true ;; emergency-services
  true ;; surgery-facilities
  u20 ;; icu-beds
  true ;; maternity-ward
  true ;; pediatric-care
  false ;; mental-health
  true ;; radiology
  true ;; laboratory
  true ;; pharmacy
  true) ;; ambulance-service
```

### Patient Referral System

#### Submit Patient Referral
```clarity
(contract-call? .referral-core submit-referral
  "PAT001"
  "Jane Doe"
  u45 ;; patient-age
  u2 ;; target-hospital
  "Cardiac arrhythmia"
  u2 ;; urgency-level (high)
  "Patient requires specialized cardiac care"
  "Cardiology")
```

#### Process Referral
```clarity
(contract-call? .referral-core process-referral
  u1 ;; referral-id
  true ;; accept
  "Referral accepted, scheduling for tomorrow")
```

#### Update Patient Medical Data
```clarity
(contract-call? .referral-core update-patient-medical-data
  "PAT001"
  "A+" ;; blood-type
  "Penicillin allergy"
  "Hypertension, Diabetes Type 2"
  "Metformin, Lisinopril"
  "Emergency Contact: John Doe 555-0199"
  "Insurance: Government Health Plan"
  "Previous cardiac episodes in 2020, 2022")
```

## Compliance & Security

This system is designed with government transparency requirements in mind:
- **Data Integrity**: Immutable blockchain records prevent tampering
- **Access Control**: Role-based permissions for different government levels
- **Privacy Balance**: Public transparency while protecting sensitive operational details
- **Audit Compliance**: Complete logging for government accountability standards

## Public Access Features

Citizens can access:
- **Real-time Attendance**: See which officials are currently on duty
- **Historical Records**: Review past attendance patterns and statistics
- **Department Performance**: Compare attendance rates across government departments
- **Meeting Participation**: Verify attendance at public meetings and hearings
- **Transparency Reports**: Regular automated reports on government attendance

## Quality Assurance

- **Government Standards Compliance**: Adherence to public sector transparency requirements
- **Continuous Monitoring**: Real-time system health and performance tracking
- **Regular Audits**: Periodic review of system operations and compliance
- **Citizen Feedback**: Public input mechanisms for system improvement

## Administrative Features

### For Department Heads
- **Staff Management**: Register and manage department officials
- **Duty Assignment**: Create and assign specific responsibilities
- **Performance Review**: Monitor staff attendance and productivity
- **Report Generation**: Create detailed attendance reports

### For Government IT Administrators
- **System Monitoring**: Track system performance and usage
- **Security Management**: Maintain access controls and authentication
- **Data Backup**: Ensure continuity of attendance records
- **Integration Support**: Connect with existing government systems

## Contributing

This project follows government software development standards. All contributions must comply with transparency regulations and undergo thorough security review.

## License

Government Open Source License - See LICENSE file for details

## Support

For technical support or government implementation assistance, please contact the system administrators through official government channels.

---

*This system is designed to strengthen democratic governance through technology-enabled transparency and accountability.*
