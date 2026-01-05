# SetupView Layout Refactor

Refactor SetupView to use a more robust layout architecture that handles window resizing gracefully, remove unused autonomous mode UI, and replace the existing plan modal with a persistent inline indicator.

## Task 1: Restructure SetupView with Scroll + Sticky Footer Pattern
**Description:** Refactor SetupView to use a robust layout with a scrollable content area and a sticky footer for the start button, preventing layout issues when the window is resized.

- [ ] Replace the current VStack layout with a VStack containing two sections: scrollable content and fixed footer
- [ ] Wrap header, project selection, feature description sections in a ScrollView
- [ ] Keep the start button outside the ScrollView in a fixed footer area
- [ ] Use `.frame(maxHeight: .infinity)` on the ScrollView to fill available space
- [ ] Remove the hardcoded `.frame(minWidth: 600, minHeight: 500)` constraint from the root view
- [ ] Test that the layout handles very short window heights gracefully

## Task 2: Remove Autonomous Mode UI ✅
**Description:** Remove the "Enable Autonomous Mode" checkbox and all related UI elements from SetupView since they don't have functional backing.

- [x] Delete the `autonomousConfigSection` computed property
- [x] Remove the reference to `autonomousConfigSection` from the main body
- [x] Remove any related bindings or helper methods for autonomous mode (if unused elsewhere)
- [x] Verify the `AutonomousConfig` model and `userPreferences` are still needed for other features, or mark for future cleanup

## Task 3: Replace Existing Plan Modal with Inline Indicator ✅
**Description:** Replace the conditional GroupBox "Existing Plan Detected" section with a subtle, persistent inline banner that appears below the header when a plan.md file is detected.

- [x] Delete the `existingPlanSection` GroupBox computed property
- [x] Create a new `ExistingPlanBanner` view component (inline in SetupView or separate file)
- [x] Design the banner as a horizontal HStack with: icon, text showing task count, "Use Existing Plan" button, and "Dismiss" button
- [x] Style the banner with a subtle background color (e.g., `.secondary.opacity(0.1)`) and rounded corners
- [x] Position the banner between the header and project selection sections
- [x] Add dismiss functionality that sets `context.existingPlan = nil`
- [x] Ensure the banner doesn't disrupt the form flow or take excessive vertical space

## Task 4: Clean Up Layout Spacing and Padding ✅
**Description:** Ensure consistent spacing throughout the refactored layout and remove any redundant padding that could cause layout issues.

- [x] Standardize VStack spacing (use 16pt for main sections)
- [x] Review and adjust GroupBox internal padding for consistency
- [x] Ensure the ScrollView has appropriate content insets
- [x] Add proper padding to the sticky footer area
- [x] Test the layout at various window sizes (narrow, short, wide, tall)

## Task 5: Update TabContentView Frame Constraints
**Description:** Review and update frame constraints in TabContentView to work harmoniously with the new SetupView layout.

- [ ] Remove or relax the `minWidth`/`minHeight` constraints if they conflict with the new flexible layout
- [ ] Ensure the content area properly fills available space without overlap with tab bar
- [ ] Test switching between SetupView and ExecutionView at various window sizes
