# Project profile (template)

The profile is the input that decides which SOPs apply. Every org SOP carries `applies_when` clauses
over these fields; instantiating a project resolves the applicable set and records why. A change to the
profile is itself a stage gate: re-run the resolution and log the diff.

```yaml
project: <name>
owner: <product owner>
openness:
  code: open | partially-closed | closed      # and which paths are closed
  content: open | partially-closed | closed   # narrative, art, data
  history: private-kept | public-filtered     # SOP-14
licences: [<code licence>, <content licence>]
data_sensitivity: none | personal | human-subjects | phi | export-controlled
obligations: [<funder data-sharing plan>, <consent/IRB>, <jurisdiction>, <contracts>]
audience: [<e.g. teenagers in classrooms>, <general public>, <internal>]
team:
  humans: [<roles>]
  agents: [<roles, which sessions, which tools>]
  external: [<institutions, collaborators>]
deployment: [<web>, <mobile>, <on-prem>, <cloud provider>]
stage: <0.x.y and what the next gate is>
```
