# Solutions — Rescu Developer Assessment

## Part C — Written Deliverables

---

### 1. Per Ticket / Feature Documentation

#### **RES-101 · Search shows results for the wrong query**

- **Root Cause:**
  - In `SearchScreen`, `TextField.onChanged` directly triggered `controller.onQueryChanged(query)` on every keystroke with zero debouncing or request throttling.
  - In the simulated backend (`FakeApiService.searchDeals`), broad queries take significantly longer than specific queries due to dynamic latency:
    $$\text{broadness} = \max(0, 1200 - \text{query.length} \times 280)\,\text{ms}$$
    For example, typing `"s"` takes ~1,200ms + jitter, whereas typing `"sushi"` takes ~180–480ms.
  - In `SearchDealsController`, each keystroke initiated an asynchronous `dealRepo.search(query)` that unconditionally called `results.assignAll(found)` when completed.
  - When a user typed quickly (e.g. `"sushi"`):
    1. The fast request for `"sushi"` completed in ~300ms and displayed sushi deals.
    2. The slow, earlier request for `"s"` completed later (~1,200ms) and overwrote `results` with deals matching `"s"` (bakery, salad, etc.).
  - This is a classic **asynchronous race condition** caused by missing debouncing and missing out-of-order response invalidation.

- **Why this fix is the right one:**
  - We implemented a two-layered defense:
    1. **Debouncing via `Timer` (300ms):**
       Every keystroke in `onQueryChanged` immediately calls `_debounceTimer?.cancel()`. Only when the user pauses typing for 300ms is `_search(trimmed)` invoked. This eliminates request spam and reduces backend load.
    2. **Double Guard (Request Sequencing + Query Verification):**
       We maintain a monotonic `_latestRequestId` counter and an `_activeQuery` string. When `dealRepo.search(query)` completes, results are applied **only if**:
       ```dart
       if (currentRequestId == _latestRequestId && query == _activeQuery) {
         results.assignAll(found);
       }
       ```
       If network latency fluctuates or an older request arrives late, it is silently discarded.
    3. **Immediate Reset on Empty Input:**
       If the user clears the text box, in-flight searches are immediately invalidated (`_latestRequestId++`), the debounce timer is cancelled, and `results` is cleared synchronously without waiting 300ms.

- **Alternatives Considered and Rejected:**
  - *Alternative 1: GetX Worker `debounce(searchQuery, ...)`*
    - **Rejected because:** It requires wrapping the query into an `RxString` (`searchQuery = ''.obs`) and binding the worker inside `onInit()`. During development with Flutter Hot Reload, `onInit()` does not re-execute for existing controllers, which can lead to uninitialized or disconnected workers during debugging. Using `Timer` from `dart:async` is explicit, deterministic, zero-dependency, and cleans up cleanly in `onClose()`.
  - *Alternative 2: Disabling the TextField while searching (blocking UI)*
    - **Rejected because:** Disabling input while typing ruins the user experience; users expect modern search inputs to be responsive and fluid.
  - *Alternative 3: Client-side search / filtering*
    - **Rejected because:** In real-world surplus food applications, catalogs are large, dynamic, and paginated on the backend. Client-side filtering does not scale and violates the API contract.

- **Edge Cases Considered:**
  - **Rapid typing / key spamming:** Handled by resetting `_debounceTimer` on each keystroke.
  - **Out-of-order network responses:** Handled by verifying `currentRequestId == _latestRequestId` and `query == _activeQuery`.
  - **Clearing search text (Backspace / Clear):** Handled immediately; cancels any pending timer, increments `_latestRequestId` to discard in-flight requests, and resets UI state immediately.
  - **Whitespace-only queries (e.g. `"   "`):** Trimmed; treated as empty search without hitting the backend.
  - **Screen disposal while request is in flight:** Handled by calling `_debounceTimer?.cancel()` inside `onClose()`.
  - **Edge cases decided not to handle:**
    - Offline search caching: Network errors are logged via `LogService.error`, but persistent offline caching of query results was left out as it was not specified in the ticket scope.

#### **RES-102 · Crash after leaving My orders**

- **Root Cause:**
  - In `PickupCountdown` (`lib/feature/order/widget/pickup_countdown.dart`), a periodic 1-second timer (`Timer.periodic`) was instantiated inside `initState()` to refresh the countdown UI via `setState(() {})`.
  - The State class did not retain a reference to this `Timer` and lacked a `dispose()` override.
  - When navigating back from the **My orders** screen, `_PickupCountdownState` was unmounted and marked defunct by the Flutter framework.
  - However, the periodic timer remained active in the Dart isolate event loop. On its next 1-second tick, it attempted to call `setState(() {})` on the disposed State object, triggering the crash: `Unhandled Exception: setState() called after dispose(): _PickupCountdownState (lifecycle state: defunct, not mounted)`.

- **Why this fix is the right one:**
  - We stored the timer reference in a private field `Timer? _timer` and implemented `dispose()` to explicitly invoke `_timer?.cancel()`.
  - In addition, inside the timer callback, we added a check to auto-cancel the timer if `widget.pickupStart.difference(DateTime.now()).isNegative`, avoiding unnecessary 1-second wakeups once the pickup window has already opened.
  - This eliminates both the crash and the background timer leak without hiding the error.

- **Alternatives Considered and Rejected:**
  - *Alternative: Wrapping `setState()` with `if (mounted)`*
    - **Rejected because:** While `if (mounted) setState(() {});` suppresses the crash, it fails to cancel the underlying `Timer.periodic`. The timer continues to run indefinitely in the background, consuming CPU and leaking memory. As noted in `PROBLEM.md`, hiding symptoms without fixing the root cause is penalized.

- **Edge Cases Considered:**
  - **Widget unmounted while countdown is active:** Handled by `_timer?.cancel()` in `dispose()`.
  - **Window already open / countdown reaches zero:** Timer cancels itself automatically via `timer.cancel()`.
  - **Edge cases decided not to handle:**
    - Device clock changes while screen is open: Handled naturally on the next tick by computing `difference(DateTime.now())`.

---

### 2. AI Usage Log

- **Tools Used:** Cursor / Antigravity AI Assistant for codebase investigation and code suggestions.

1. **Bug RES-101: Search shows results for the wrong query**
   - **My Prompt:** "Result doesn't match with input, please check file search_deals_controller.dart"
   - **AI Suggestion:** Recommended using GetX's built-in `debounce` worker inside `onInit()` listening to an auxiliary `RxString searchQuery`.
   - **Why it was wrong:** `onInit()` does not re-run during Flutter Hot Reload if the controller is already in memory, causing the worker to be uninitialized or miss updates. Additionally, `debounce` alone without query verification didn't prevent race conditions if in-flight requests resolved out of order.
   - **My Fix:** Replaced GetX `debounce` with a standard `dart:async` `Timer` (`_debounceTimer?.cancel()`) and added a Double Guard (`_latestRequestId` + `query == _activeQuery`) to strictly discard stale responses.

2. **Bug RES-102: Crash after leaving My orders**
   - **My Prompt:** "### RES-102 · Crash after leaving My orders E/flutter (14779): [ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: setState() called after dispose():"
   - **AI Suggestion:** Initial generic Flutter advice suggested checking `if (mounted)` before calling `setState()`.
   - **Why it was wrong:** Checking `if (mounted)` only suppresses the exception while leaving the `Timer.periodic` running indefinitely in the background, leading to a permanent memory and CPU leak.
   - **My Fix:** Stored the `Timer` reference in `_timer` and properly cancelled it in `dispose()`, plus auto-cancelling when the pickup window opens.

---

### 3. Design Questions

- **Q1: In this codebase, what is the difference between a `GetxController`'s lifecycle and a widget `State`'s lifecycle? Name one bug from Part A that exists because of confusion between the two.**
  - *(To be answered as other tickets are investigated)*

- **Q2: When does wrapping a large subtree in a single `Obx` hurt you? How do you decide how tightly to scope reactivity?**
  - *(To be answered as other tickets are investigated)*

- **Q3: How would you write an automated test that would have caught RES-106 before release? What (if anything) would you change in the code to make such a test possible?**
  - *(To be answered as other tickets are investigated)*

---

### 4. Time Spent & Next Steps

- **Time Spent on RES-101:** ~30–45 minutes (investigation, reproduction, implementation, and documentation).
- **Next Steps:** Proceed with the remaining bug tickets in Part A (e.g. RES-102 crash after leaving My Orders).
