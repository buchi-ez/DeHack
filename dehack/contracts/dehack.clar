;; Decentralized Hackathon Platform
;; A platform for organizing hackathons with automated registration,
;; project submissions, transparent judging, and prize distribution

;; SIP-010 token trait
(define-trait token-standard-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
  )
)

;; Constants
(define-constant error-not-found (err u404))
(define-constant error-unauthorized (err u401))
(define-constant error-invalid-input (err u400))
(define-constant error-already-exists (err u409))
(define-constant error-deadline-passed (err u410))
(define-constant error-invalid-status (err u411))
(define-constant error-max-reached (err u413))

;; Hackathon events
(define-map event-registry
  { event-id: uint }
  {
    name: (string-utf8 128),
    description: (string-utf8 512),
    organizer: principal,
    created-at: uint,
    registration-start: uint,
    registration-end: uint,
    event-start: uint,
    event-end: uint,
    submission-deadline: uint,
    tracks: (list 5 (string-ascii 64)),
    prize-pool: uint,
    max-team-size: uint,
    max-hackers: uint,
    current-hackers: uint,
    status: (string-ascii 16)
  }
)

;; Hackathon participants
(define-map hacker-registry
  { event-id: uint, hacker: principal }
  {
    registered-at: uint,
    team-id: (optional uint),
    skills: (list 5 (string-ascii 32)),
    status: (string-ascii 16)
  }
)

;; Hackathon teams
(define-map team-registry
  { event-id: uint, team-id: uint }
  {
    name: (string-utf8 64),
    description: (string-utf8 256),
    created-at: uint,
    captain: principal,
    members: (list 6 principal),
    project-id: (optional uint),
    selected-tracks: (list 3 (string-ascii 64))
  }
)

;; Project submissions
(define-map project-registry
  { event-id: uint, project-id: uint }
  {
    team-id: uint,
    title: (string-utf8 128),
    description: (string-utf8 512),
    submitted-at: uint,
    repo-url: (string-utf8 256),
    demo-url: (optional (string-utf8 256)),
    tracks: (list 3 (string-ascii 64)),
    tech-stack: (list 8 (string-ascii 32)),
    status: (string-ascii 16),
    final-score: (optional uint),
    ranking: (optional uint)
  }
)

;; Hackathon judges
(define-map judge-registry
  { event-id: uint, judge: principal }
  {
    name: (string-utf8 64),
    expertise: (list 3 (string-ascii 32)),
    added-at: uint,
    status: (string-ascii 16),
    projects-scored: uint
  }
)

;; Judge evaluations
(define-map evaluation-registry
  { event-id: uint, project-id: uint, judge: principal }
  {
    innovation-score: uint,
    technical-score: uint,
    presentation-score: uint,
    feedback: (string-utf8 256),
    submitted-at: uint,
    total-score: uint
  }
)

;; Hackathon prizes
(define-map prize-registry
  { event-id: uint, prize-id: uint }
  {
    title: (string-utf8 64),
    track: (optional (string-ascii 64)),
    amount: uint,
    winner-project-id: (optional uint),
    claimed: bool
  }
)

;; Next available IDs
(define-data-var next-event-id uint u1)
(define-map next-team-id { event-id: uint } { id: uint })
(define-map next-project-id { event-id: uint } { id: uint })
(define-map next-prize-id { event-id: uint } { id: uint })

;; Create a new hackathon event
(define-public (create-hackathon
                (name (string-utf8 128))
                (description (string-utf8 512))
                (registration-start uint)
                (registration-end uint)
                (event-start uint)
                (event-end uint)
                (submission-deadline uint)
                (tracks (list 5 (string-ascii 64)))
                (prize-pool uint)
                (max-team-size uint)
                (max-hackers uint))
  (let
    ((event-id (var-get next-event-id)))
    
    (asserts! (> (len tracks) u0) error-invalid-input)
    (asserts! (< registration-start registration-end) error-invalid-input)
    (asserts! (< registration-end event-start) error-invalid-input)
    (asserts! (< event-start event-end) error-invalid-input)
    (asserts! (<= event-end submission-deadline) error-invalid-input)
    (asserts! (> max-team-size u0) error-invalid-input)
    (asserts! (> max-hackers u0) error-invalid-input)
    (asserts! (> prize-pool u0) error-invalid-input)
    
    (map-set event-registry
      { event-id: event-id }
      {
        name: name,
        description: description,
        organizer: tx-sender,
        created-at: block-height,
        registration-start: registration-start,
        registration-end: registration-end,
        event-start: event-start,
        event-end: event-end,
        submission-deadline: submission-deadline,
        tracks: tracks,
        prize-pool: prize-pool,
        max-team-size: max-team-size,
        max-hackers: max-hackers,
        current-hackers: u0,
        status: "upcoming"
      }
    )
    
    (map-set next-team-id { event-id: event-id } { id: u1 })
    (map-set next-project-id { event-id: event-id } { id: u1 })
    (map-set next-prize-id { event-id: event-id } { id: u1 })
    
    (try! (stx-transfer? prize-pool tx-sender (as-contract tx-sender)))
    
    (var-set next-event-id (+ event-id u1))
    
    (ok event-id)
  )
)

;; Register as a hacker
(define-public (register-hacker
                (event-id uint)
                (skills (list 5 (string-ascii 32))))
  (let
    ((event (unwrap! (map-get? event-registry { event-id: event-id }) error-not-found)))
    
    (asserts! (is-eq (get status event) "registration") error-invalid-status)
    (asserts! (< (get current-hackers event) (get max-hackers event)) error-max-reached)
    (asserts! (>= block-height (get registration-start event)) error-deadline-passed)
    (asserts! (<= block-height (get registration-end event)) error-deadline-passed)
    (asserts! (is-none (map-get? hacker-registry { event-id: event-id, hacker: tx-sender })) error-already-exists)
    
    (map-set hacker-registry
      { event-id: event-id, hacker: tx-sender }
      {
        registered-at: block-height,
        team-id: none,
        skills: skills,
        status: "registered"
      }
    )
    
    (map-set event-registry
      { event-id: event-id }
      (merge event { current-hackers: (+ (get current-hackers event) u1) })
    )
    
    (ok true)
  )
)

;; Create a hackathon team
(define-public (create-team
                (event-id uint)
                (name (string-utf8 64))
                (description (string-utf8 256))
                (selected-tracks (list 3 (string-ascii 64))))
  (let
    ((event (unwrap! (map-get? event-registry { event-id: event-id }) error-not-found))
     (hacker (unwrap! (map-get? hacker-registry { event-id: event-id, hacker: tx-sender }) error-not-found))
     (team-counter (unwrap! (map-get? next-team-id { event-id: event-id }) error-not-found))
     (team-id (get id team-counter)))
    
    (asserts! (or (is-eq (get status event) "registration") (is-eq (get status event) "active")) error-invalid-status)
    (asserts! (is-none (get team-id hacker)) error-already-exists)
    (asserts! (> (len selected-tracks) u0) error-invalid-input)
    
    (map-set team-registry
      { event-id: event-id, team-id: team-id }
      {
        name: name,
        description: description,
        created-at: block-height,
        captain: tx-sender,
        members: (list tx-sender),
        project-id: none,
        selected-tracks: selected-tracks
      }
    )
    
    (map-set hacker-registry
      { event-id: event-id, hacker: tx-sender }
      (merge hacker { team-id: (some team-id), status: "teamed" })
    )
    
    (map-set next-team-id { event-id: event-id } { id: (+ team-id u1) })
    
    (ok team-id)
  )
)

;; Join a hackathon team
(define-public (join-team (event-id uint) (team-id uint))
  (let
    ((event (unwrap! (map-get? event-registry { event-id: event-id }) error-not-found))
     (hacker (unwrap! (map-get? hacker-registry { event-id: event-id, hacker: tx-sender }) error-not-found))
     (team (unwrap! (map-get? team-registry { event-id: event-id, team-id: team-id }) error-not-found)))
    
    (asserts! (or (is-eq (get status event) "registration") (is-eq (get status event) "active")) error-invalid-status)
    (asserts! (is-none (get team-id hacker)) error-already-exists)
    (asserts! (< (len (get members team)) (get max-team-size event)) error-max-reached)
    
    (let
      ((updated-members (unwrap! (as-max-len? (append (get members team) tx-sender) u6) error-max-reached)))
      
      (map-set team-registry
        { event-id: event-id, team-id: team-id }
        (merge team { members: updated-members })
      )
      
      (map-set hacker-registry
        { event-id: event-id, hacker: tx-sender }
        (merge hacker { team-id: (some team-id), status: "teamed" })
      )
      
      (ok true)
    )
  )
)

;; Submit a hackathon project
(define-public (submit-project
                (event-id uint)
                (team-id uint)
                (title (string-utf8 128))
                (description (string-utf8 512))
                (repo-url (string-utf8 256))
                (demo-url (optional (string-utf8 256)))
                (tracks (list 3 (string-ascii 64)))
                (tech-stack (list 8 (string-ascii 32))))
  (let
    ((event (unwrap! (map-get? event-registry { event-id: event-id }) error-not-found))
     (team (unwrap! (map-get? team-registry { event-id: event-id, team-id: team-id }) error-not-found))
     (project-counter (unwrap! (map-get? next-project-id { event-id: event-id }) error-not-found))
     (project-id (get id project-counter)))
    
    (asserts! (is-team-member tx-sender (get members team)) error-unauthorized)
    (asserts! (or (is-eq (get status event) "active") 
                 (<= block-height (get submission-deadline event))) error-invalid-status)
    (asserts! (is-none (get project-id team)) error-already-exists)
    (asserts! (> (len tracks) u0) error-invalid-input)
    
    (map-set project-registry
      { event-id: event-id, project-id: project-id }
      {
        team-id: team-id,
        title: title,
        description: description,
        submitted-at: block-height,
        repo-url: repo-url,
        demo-url: demo-url,
        tracks: tracks,
        tech-stack: tech-stack,
        status: "submitted",
        final-score: none,
        ranking: none
      }
    )
    
    (map-set team-registry
      { event-id: event-id, team-id: team-id }
      (merge team { project-id: (some project-id) })
    )
    
    (map-set next-project-id { event-id: event-id } { id: (+ project-id u1) })
    
    (ok project-id)
  )
)

;; Check if a principal is a team member
(define-private (is-team-member (member principal) (members (list 6 principal)))
  (get found (fold check-member members { target: member, found: false }))
)

(define-private (check-member (current principal) (accumulator { target: principal, found: bool }))
  (if (get found accumulator) accumulator { target: (get target accumulator), found: (is-eq current (get target accumulator)) })
)

;; Add a judge to hackathon
(define-public (add-judge
                (event-id uint)
                (judge principal)
                (name (string-utf8 64))
                (expertise (list 3 (string-ascii 32))))
  (let
    ((event (unwrap! (map-get? event-registry { event-id: event-id }) error-not-found)))
    
    (asserts! (is-eq tx-sender (get organizer event)) error-unauthorized)
    (asserts! (> (len expertise) u0) error-invalid-input)
    
    (map-set judge-registry
      { event-id: event-id, judge: judge }
      {
        name: name,
        expertise: expertise,
        added-at: block-height,
        status: "invited",
        projects-scored: u0
      }
    )
    
    (ok true)
  )
)

;; Submit project evaluation
(define-public (evaluate-project
                (event-id uint)
                (project-id uint)
                (innovation-score uint)
                (technical-score uint)
                (presentation-score uint)
                (feedback (string-utf8 256)))
  (let
    ((event (unwrap! (map-get? event-registry { event-id: event-id }) error-not-found))
     (judge-data (unwrap! (map-get? judge-registry { event-id: event-id, judge: tx-sender }) error-not-found))
     (project (unwrap! (map-get? project-registry { event-id: event-id, project-id: project-id }) error-not-found)))
    
    (asserts! (is-eq (get status event) "judging") error-invalid-status)
    (asserts! (is-eq (get status judge-data) "active") error-invalid-status)
    (asserts! (and (<= innovation-score u10) (>= innovation-score u1)) error-invalid-input)
    (asserts! (and (<= technical-score u10) (>= technical-score u1)) error-invalid-input)
    (asserts! (and (<= presentation-score u10) (>= presentation-score u1)) error-invalid-input)
    
    (let
      ((total-score (+ (+ innovation-score technical-score) presentation-score)))
      
      (map-set evaluation-registry
        { event-id: event-id, project-id: project-id, judge: tx-sender }
        {
          innovation-score: innovation-score,
          technical-score: technical-score,
          presentation-score: presentation-score,
          feedback: feedback,
          submitted-at: block-height,
          total-score: total-score
        }
      )
      
      (map-set judge-registry
        { event-id: event-id, judge: tx-sender }
        (merge judge-data { projects-scored: (+ (get projects-scored judge-data) u1) })
      )
      
      (ok true)
    )
  )
)

;; Add a hackathon prize
(define-public (add-prize
                (event-id uint)
                (title (string-utf8 64))
                (track (optional (string-ascii 64)))
                (amount uint))
  (let
    ((event (unwrap! (map-get? event-registry { event-id: event-id }) error-not-found))
     (prize-counter (unwrap! (map-get? next-prize-id { event-id: event-id }) error-not-found))
     (prize-id (get id prize-counter)))
    
    (asserts! (is-eq tx-sender (get organizer event)) error-unauthorized)
    (asserts! (> amount u0) error-invalid-input)
    
    (map-set prize-registry
      { event-id: event-id, prize-id: prize-id }
      {
        title: title,
        track: track,
        amount: amount,
        winner-project-id: none,
        claimed: false
      }
    )
    
    (map-set next-prize-id { event-id: event-id } { id: (+ prize-id u1) })
    
    (ok prize-id)
  )
)

;; Claim a hackathon prize
(define-public (claim-prize (event-id uint) (prize-id uint))
  (let
    ((event (unwrap! (map-get? event-registry { event-id: event-id }) error-not-found))
     (prize (unwrap! (map-get? prize-registry { event-id: event-id, prize-id: prize-id }) error-not-found))
     (project-id (unwrap! (get winner-project-id prize) error-not-found))
     (project (unwrap! (map-get? project-registry { event-id: event-id, project-id: project-id }) error-not-found))
     (team (unwrap! (map-get? team-registry { event-id: event-id, team-id: (get team-id project) }) error-not-found)))
    
    (asserts! (is-eq (get status event) "completed") error-invalid-status)
    (asserts! (not (get claimed prize)) error-already-exists)
    (asserts! (is-team-member tx-sender (get members team)) error-unauthorized)
    
    (map-set prize-registry
      { event-id: event-id, prize-id: prize-id }
      (merge prize { claimed: true })
    )
    
    (try! (as-contract (stx-transfer? (get amount prize) tx-sender tx-sender)))
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-hackathon-details (event-id uint))
  (ok (unwrap! (map-get? event-registry { event-id: event-id }) error-not-found))
)

(define-read-only (get-hacker-details (event-id uint) (hacker principal))
  (ok (unwrap! (map-get? hacker-registry { event-id: event-id, hacker: hacker }) error-not-found))
)

(define-read-only (get-team-details (event-id uint) (team-id uint))
  (ok (unwrap! (map-get? team-registry { event-id: event-id, team-id: team-id }) error-not-found))
)

(define-read-only (get-project-details (event-id uint) (project-id uint))
  (ok (unwrap! (map-get? project-registry { event-id: event-id, project-id: project-id }) error-not-found))
)