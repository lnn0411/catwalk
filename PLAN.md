## T3-T7 Implementation Plan

### Subtasks

1. Type definitions
   - `src/types/cat.ts`: export `CatBreed`, `CatLevel`, `SlotStatus`, `TaskStatus`, `Cat`, `EggSlot`
   - `src/types/activity.ts`: export `SignInState`, `NewbieGoal`, `EventCard`
   - `src/types/common.ts`: export `RewardItem`

2. Zustand stores
   - `src/store/catStore.ts`: `useCatStore` with `cats`, `slots`, `addCat(cat: Cat)`, `updateSlot(id: string, patch: Partial<EggSlot>)`
   - `src/store/energyStore.ts`: `useEnergyStore` with `steps`, `energy`, `maxEnergy`, `addSteps(amount: number)`, `setSteps(steps: number)`, `fillEnergy()`
   - `src/store/signInStore.ts`: `useSignInStore` with `signIn`, `setSignIn(signIn: SignInState)`
   - `src/store/newbieStore.ts`: `useNewbieStore` with `goals`, `completeGoal(id: number)`, `claimGoal(id: number)`

3. Hooks
   - `src/hooks/useStepCounter.ts`: development mock hook updates store every second by `speed`; production hook returns empty unauthorized implementation
   - `src/hooks/useEnergy.ts`: read `energy`, `maxEnergy`, `fillEnergy`; derive `percent`

4. Routes and pages
   - Replace `src/App.tsx` with `BrowserRouter`, redirect `/` to `/boot`, and define 11 routes.
   - Create all page placeholders under `src/pages/`.

5. Components
   - `src/components/EnergyBar.tsx`: `current/max/variant`, 300ms linear width transition
   - `src/components/CurrencyBar.tsx`: top currency display for coins, gems, optional hearts
   - `src/components/BottomNav.tsx`: 5 tabs, router-aware active state
   - `src/components/DevTools.tsx`: development-only floating panel with step, energy, route, speed, hatch, and dormant actions

6. Cleanup and verification
   - Remove CRA default `src/App.css`, `src/App.test.tsx`, `src/logo.svg`.
   - Add Android `ACTIVITY_RECOGNITION` permission.
   - Run `npm run build`.
   - Commit with `T3-T7: types + stores + hooks + 11 pages + 4 components`.

### Dependencies

Types are needed before stores. Stores are needed before hooks and DevTools. Pages can be created independently. App routing depends on pages and DevTools.

### Risks

The installed router is v7, while the spec mentions v6. The v6-style APIs used here (`BrowserRouter`, `Routes`, `Route`, `Navigate`, `NavLink`, hooks) remain available. CRA with React 19 type packages can expose stricter typing, so components avoid fragile implicit children typing.

### Recommended Order

Types, stores, hooks, pages, components, App routing, Android permission, cleanup, build, commit.
