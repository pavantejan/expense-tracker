1. Work on ONE task at a time.

2. Before changing code:
   - Inspect the existing implementation.
   - Explain briefly what will be changed.

3. Do NOT implement future tasks proactively.

4. After making the requested change:
   - Run flutter analyze.
   - Fix only issues caused by the current change.
   - Stop.

5. Do NOT move to the next feature until the user explicitly says:
   "continue", "next", or gives the next task.

6. Never rewrite working architecture unnecessarily.

7. Preserve existing functionality.

8. For Drift/database changes:
   - Update schema carefully.
   - Run build_runner when required.
   - Run flutter analyze.
   - Stop for user testing.

9. For every meaningful checkpoint:
   - Show changed files.
   - Show analyze/build result.
   - Wait for user confirmation.

10. If something is ambiguous:
    Ask before making a large architectural decision.