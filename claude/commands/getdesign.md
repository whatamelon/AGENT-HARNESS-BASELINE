# getdesign

Load the shared design operating system before product/UI/UX/visual work.

## Procedure

1. Run or conceptually follow:
   ```bash
   getdesign
   # or: ~/.config/claude-sync/bin/getdesign.sh
   ```
2. Read the nearest project-local design docs discovered by the command.
3. Read the global shared files:
   - `~/getdesign.md`
   - `~/DESIGN.md`
4. Summarize the active design context before editing or reviewing UI:
   - Product goal
   - Primary user/action
   - Surface/component/page
   - Existing design system/style
   - Constraints
   - Validation plan
5. Use relevant design skills when available: `frontend-design`, `ui-ux-pro-max`, `web-design-guidelines`, `tailwind-design-system`, `shadcn-ui`, framework-specific UI skills.
6. Validate visually when possible and include evidence.

## Stop condition

Continue until the design context is identified, applied, and the verification evidence is clear.


## Project setup shortcuts

```bash
getdesign init          # copy shared DESIGN.md into this project
getdesign add cursor    # install a catalog inspiration into this project
getdesign doctor        # verify global shared links
```
