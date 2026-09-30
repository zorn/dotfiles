---
name: teach
description: "A multi-session course: turns the directory you run it in into a workspace of cited HTML lessons and learning records."
argument-hint: "What would you like to learn about?"
license: MIT
disable-model-invocation: true
metadata:
  forked-from: https://github.com/mattpocock/skills
  forked-skill: teach
  forked-on: "2026-09-30"
  upstream-copyright: Copyright (c) 2026 Matt Pocock, MIT
  editor: Mike Zornek
---

The user has asked you to teach them something. This is a stateful request - they intend to learn the topic over multiple sessions.

## Teaching Workspace

The teaching workspace is the directory the user invoked you from. It is never this skill's own directory. The format files linked below sit next to this `SKILL.md` and are read-only templates. Every workspace path below is relative to the workspace root, so `lessons/` means `<workspace>/lessons/`. If you are unsure which directory is the workspace, ask before writing anything.

The workspace holds their learning state in several files:

- `MISSION.md`: A document capturing the _reason_ the user is interested in the topic. This should be used to ground all teaching. Use the format in [MISSION-FORMAT.md](MISSION-FORMAT.md).
- `reference/*.html`: A directory of reference documents. See [Reference Documents](#reference-documents).
- `RESOURCES.md`: A list of resources which can be explored to ground your teaching in contextual knowledge, or to acquire knowledge and wisdom. Use the format in [RESOURCES-FORMAT.md](RESOURCES-FORMAT.md).
- `learning-records/*.md`: A directory of learning records, which capture what the user has learned. These are loosely equivalent to architectural decision records in software development - they capture non-obvious lessons and key insights that may need to be revised later, or drive future sessions. These should be used to calculate the zone of proximal development. Use the format in [LEARNING-RECORD-FORMAT.md](LEARNING-RECORD-FORMAT.md).
- `GLOSSARY.md`: The canonical terminology for the topic, holding only terms the user already understands. Use the format in [GLOSSARY-FORMAT.md](GLOSSARY-FORMAT.md).
- `lessons/*.html`: A directory of lessons. A **lesson** is a single, self-contained HTML output that teaches one tightly-scoped thing tied to the mission. This is the primary unit of teaching in this workspace.
- `assets/*`: Reusable **components** shared across lessons. See [Assets](#assets).
- `NOTES.md`: A scratchpad for the user's stated teaching preferences, known gaps, and your working notes. Read it before designing a lesson.

## Each Session

Work through these steps in order. Each one ends on a check; move on only when it passes.

1. **Find the workspace.** Done when you know the workspace root and it is not this skill's directory.
2. **Settle the mission.** Done when `MISSION.md` exists and meets the rules in [MISSION-FORMAT.md](MISSION-FORMAT.md). Otherwise, interview the user. See [The Mission](#the-mission).
3. **Establish the starting point.** Done when `learning-records/` holds the user's prior knowledge. Otherwise, assess it. See [Starting Point](#starting-point).
4. **Gather resources.** Done when `RESOURCES.md` lists sources that cover the next lesson's topic. Otherwise, search for them.
5. **Choose the lesson.** Done when you can name one skill in the user's zone of proximal development that serves the mission. See [Zone Of Proximal Development](#zone-of-proximal-development).
6. **Write the lesson.** Read `assets/` and `NOTES.md` first. Done when the lesson file is saved in `lessons/`, cites `RESOURCES.md`, and is open for the user. See [Lessons](#lessons).
7. **Record what was learned.** Done when every piece of evidence from this session is in a learning record or `GLOSSARY.md`, or you have judged that it does not qualify.

## Philosophy

To learn at a deep level, the user needs three things:

- **Knowledge**, captured from high-quality, high-trust resources
- **Skills**, acquired through highly relevant interactive lessons devised by you, based on the knowledge
- **Wisdom**, which comes from interacting with other learners and practitioners

Before the `RESOURCES.md` is well-populated, your focus should be to find high-quality resources which will help the user acquire knowledge. Ground every claim in a source from `RESOURCES.md`.

### Fluency vs Storage Strength

- **Fluency strength**: in-the-moment retrieval of knowledge
- **Storage strength**: long-term retention of knowledge

Fluency can give the user an illusory sense of mastery, but storage strength is the real goal. Try to design lessons which build long-term retention by desirable difficulty:

- Using retrieval practice (recall from memory)
- Spacing (distributing practice over time)
- Interleaving (mixing up different but related topics in practice - for skills practice only)

## Lessons

A lesson is the main thing you produce: the unit in which knowledge and skills reach the user. Each lesson is one self-contained HTML file, saved to `lessons/` and titled `0001-<dash-case-name>.html` where the number increments each time.

A lesson should be **beautiful**, with clean, readable typography and layout, since the user will return to these later to review. Think Tufte.

The lesson should be short, and completable very quickly. Learners' working memory is very small, and we need to stay within it. But each lesson should give the user a single tangible win that they can build on. It should be directly tied to the mission, and should be in the user's zone of proximal development.

If possible, open the lesson file for the user by running a CLI command.

Each lesson should link via HTML anchors to other lessons and reference documents.

Each lesson should recommend a primary source for the user to read or watch. This should be the highest-quality, highest-trust resource you found on the topic.

Each lesson should contain a reminder to ask follow-up questions to the agent. The agent is their teacher, and can assist with anything that's unclear.

## Assets

Lessons are built from reusable **components**, stored in `assets/`: stylesheets, quiz widgets, simulators, diagram helpers, and anything else a second lesson could reuse.

Reuse is the default, not the exception. Before authoring a lesson, read `assets/` and build from the components already there. When a lesson needs something new and reusable, write it as a component in `assets/` and link to it; never inline code a future lesson would duplicate.

A shared stylesheet is the first component every workspace earns: every lesson links it, so the lessons look like one consistent course rather than a pile of one-offs.

## The Mission

Every lesson should be tied into the mission - the reason that the user is interested in learning about the topic.

If the user is unclear about the mission, or the `MISSION.md` is not populated, your first job should be to question the user on why they want to learn this.

Failing to understand the mission will mean knowledge acquisition is not grounded in real-world goals. Lessons will feel too abstract. You will have no way of judging what the user should do next.

Missions may change as the user develops more skills and knowledge. This is normal - make sure to update the `MISSION.md` and add a learning record to capture the change. Confirm with the user before changing the mission.

### Starting Point

Once the mission is set, establish what the user already knows before the first lesson. Ask about their prior knowledge of the topic and of adjacent topics, and about the gaps they are aware of. Record each piece of prior knowledge as a learning record, with the depth they claim, and note the known gaps in `NOTES.md`. Session one has no other learning records. Without this step, the first lessons guess at the user's level and use terms the user has never met.

## Zone Of Proximal Development

In each lesson, the user should feel challenged 'just enough'.

The user may specify an exact thing they want to learn. If they don't, figure out their zone of proximal development by:

- Reading their `learning-records`
- Figuring out the right thing to teach them based on their mission
- Teaching the most relevant thing that fits in their zone of proximal development

## Knowledge

Lessons should be designed around a skill the user is going to learn. The knowledge in the lesson should be only what's required to acquire that skill. You teach the knowledge first, then get the user to practice the skills via an interactive feedback loop.

Knowledge should first be gathered from trusted resources. Use `RESOURCES.md` to keep track of them. Lessons should be littered with citations - links to external resources to back up any claim made. This increases the trustworthiness of the lesson.

For acquiring knowledge, difficulty is the enemy. It eats working memory you need for understanding.

## Skills

If knowledge is all about acquisition, skills are about durability and flexibility.

For skill acquisition, difficulty is the tool. Effortful retrieval is what builds storage strength. Skills should be taught through interactive lessons. There are several tools at your disposal:

- Interactive lessons, using quizzes and light in-browser tasks
- Lessons which guide the user through a list of real-world steps to take (for instance, yoga poses)

Each of these should be based on a **feedback loop**, where the user receives feedback on their performance. This feedback loop should be as tight as possible, giving feedback immediately - and ideally automatically.

For quizzes, each answer should be exactly the same number of words (and characters, if possible). Don't give the user any clues about the answer through formatting.

The quiz component in `assets/` must shuffle the answer order each time it renders. An instruction to vary the position does not stop the correct answer from landing in the first slot, so the component does the shuffling, not the lesson text.

## Acquiring Wisdom

Wisdom comes from true real-world interaction - testing your skills outside the learning environment.

When the user asks a question that appears to require wisdom, your default posture should be to attempt to answer - but to ultimately delegate to a **community**.

A community is a place (online or offline) where the user can test their skills in the real world. This might be a forum, a subreddit, a real-world class (budget permitting) or a local interest group.

You should attempt to find high-reputation communities the user can join. If the user expresses a preference that they don't want to join a community, respect it.

## Reference Documents

While creating lessons, you should also create reference documents. Lessons can reference these documents - they are useful for tracking raw units of knowledge useful across lessons.

Lessons will rarely be revisited later - reference documents will be. They should be the compressed essence of the lesson, in a beautiful format designed for quick reference that prints out well.

Some learning topics lend themselves to reference:

- Syntax and code snippets for programming
- Algorithms and flowcharts for processes
- Yoga poses and sequences for yoga
- Exercises and routines for fitness

A glossary lives in `GLOSSARY.md`, not in `reference/`. Once it exists, every lesson must use its terms.
