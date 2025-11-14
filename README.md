# DeHack

## Overview

DeHack is a decentralized hackathon management system that automates key aspects of hackathon operations, including event creation, participant registration, team formation, project submissions, judging, and prize distribution. It provides a transparent workflow that allows organizers, hackers, teams, and judges to interact through on-chain logic.

## Key Features

* Creation of fully on-chain hackathon events
* Registration and verification of hackers
* Automated team creation and membership tracking
* Structured project submission system with track selection and tech stacks
* Judge onboarding and scoring
* Transparent and immutable prize allocation
* Strict validation to enforce deadlines, limits, and event phases

## Contract Components

### Maps

* **coding-events:** Stores event metadata such as timelines, tracks, pool size, and status
* **hackers:** Stores registered hackers, skills, and team assignments
* **coding-teams:** Stores team information including members, project links, and tracks
* **project-submissions:** Records all project details with scoring and rankings
* **event-judges:** Tracks judges, their expertise, and scoring status
* **project-evaluations:** Stores all judge evaluations and score breakdowns
* **event-prizes:** Defines prizes, track-specific awards, and claim state
* **Counters:** next-event-id, next-team-id, next-project-id, next-prize-id

### Error Handling

Uses error constants for common failure cases including:

* Unauthorized actions
* Invalid states or deadlines
* Duplicate entries
* Maximum capacity reached
* Not found errors

## Core Functions

### Event Management

* **create-hackathon:** Creates a new event with timelines, tracks, pool funding, and participation limits

### Hacker Management

* **register-hacker:** Registers a participant for an event, validating timelines and capacity

### Team Management

* **create-team:** Allows a registered hacker to create a team, assign tracks, and become captain

## Flow Summary

1. Organizer creates an event.
2. Hackers register during the allowed period.
3. Registered users can form teams and join tracks.
4. Teams submit projects before the deadline.
5. Judges evaluate submissions.
6. Prizes are awarded transparently based on rankings.

## Summary

DeHack provides a complete, structured framework for running decentralized hackathons. Its data structures and validation logic ensure fairness, transparency, and automation throughout every phase, from registration to prize distribution.
