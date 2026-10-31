# Shift Scheduler

A Next.js scheduling app inspired by workload planners like Monday.com. Managers can drag shifts across a calendar, see real-time conflicts and warnings, and monitor staffing coverage and pay budget independently.

## Stack

- Next.js App Router with TypeScript
- TanStack Query for server state and optimistic updates
- TanStack Table for the roster/reporting table
- dnd-kit for drag and drop
- Tailwind CSS for styling
- Prisma + Postgres for persistence
- Zod for shared validation
- Vitest for unit tests

## What is included

- Calendar workspace with:
  Drag from an unassigned pool onto employee rows
  Reassign shifts between employees
  Local conflict preview while dragging
  Optimistic updates and rollback-ready mutation flow
  Session undo stack
  Keyboard assignment flow
- Coverage view:
  Required vs scheduled managers and staff by department/time block
- Pay view:
  Scheduled pay vs department budget by pay period
- Roster view:
  Sortable, filterable, exportable employee table
- Conflict engine:
  Pure shared function with unit tests for all hard conflicts and soft warnings
- Seed data:
  Three departments, about fifteen employees, varied restrictions, and a seeded week of assigned and unassigned shifts

## Project structure

- [app/page.tsx](C:/Users/Ryver/Documents/Scheduler/app/page.tsx)
- [components/calendar/calendar-board.tsx](C:/Users/Ryver/Documents/Scheduler/components/calendar/calendar-board.tsx)
- [lib/conflict-engine.ts](C:/Users/Ryver/Documents/Scheduler/lib/conflict-engine.ts)
- [tests/conflict-engine.test.ts](C:/Users/Ryver/Documents/Scheduler/tests/conflict-engine.test.ts)
- [prisma/schema.prisma](C:/Users/Ryver/Documents/Scheduler/prisma/schema.prisma)
- [prisma/seed.ts](C:/Users/Ryver/Documents/Scheduler/prisma/seed.ts)

## Setup

1. Install dependencies:

```bash
npm install
```

2. Copy the environment file and set your Postgres connection:

```bash
cp .env.example .env
```

3. Generate Prisma client and apply your database migration:

```bash
npx prisma generate
npx prisma migrate dev --name init
```

4. Seed the database:

```bash
npm run prisma:seed
```

5. Start the app:

```bash
npm run dev
```

## Test the conflict engine

```bash
npm run test
```

The test suite covers every hard conflict and soft warning with at least one passing and one failing case.

## API routes

- `GET /api/shifts?start&end&departmentId`
- `POST /api/shifts`
- `PATCH /api/shifts/:id`
- `DELETE /api/shifts/:id`
- `POST /api/shifts/validate`
- `GET /api/employees`
- `PATCH /api/employees/:id/restrictions`
- `GET /api/coverage?departmentId&start&end`
- `GET /api/pay?departmentId&periodStart&periodEnd`
- `POST /api/shifts/publish`

## Notes

- The current API layer uses an in-memory store backed by the same seed dataset for immediate local interaction in the UI, while Prisma schema and seed assets are included for the Postgres-backed persistence layer.
- Validation is shared through Zod schemas and the pure conflict engine so the client preview and server commit path stay aligned.
