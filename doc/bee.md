---
title: BEE
section: 1
source: love @VERSION@
manual: love manual
---

# NAME

bee - a coding agent in the terminal, and the protocol its sessions talk by

# SYNOPSIS

**love bee** \[**-y**\] \[**--plain**\] \[*prompt* ...\]

**love bee --list**

**love bee --send** *name* *text* ...

**love bee --spawn** *name* *dir* \[**-y**\] *prompt* ...

**love bee --stop** *name*

**love bee --serve** \[**-y**\] \[*prompt* ...\]

**love bee --mcp**

**love bee --lock** \[**--heavy**\] \[**--out** *dir*\] **--** *command* ...

**love bee --avatar** \[*name*\]

**love bee -s** \| **--screensaver** \[*name*\]

# DESCRIPTION

**bee** puts a model to work in the current directory. The model's tools:

- **read_file**, **write_file** and **edit_file**;
- **shell**, which runs a command line in **lush -a** (this binary's shell, with love's own verbs ahead of PATH);
- **list_sessions** and **send_message**, described under SESSIONS AND MESSAGES;
- **start_job**, **check_job** and **stop_job**, and **spawn_bee** and **stop_bee**, described under JOBS AND WORKERS;
- **lock_acquire**, **lock_release** and **lock_list**, described under LOCKS;
- **queue_row**, **queue_lead**, **queue_land** and **queue_landed**, described under THE MERGE QUEUE.
- in a pane of **love inle**, **pane_list**, **pane_read**, **pane_type**, **pane_open**, **pane_focus** and **pane_close**: the desktop's other panes by id, read as text, typed into as keys (a newline is Enter, and the answer is the pane once quiet), opened beside, given the keyboard, closed. The model's own pane is never typed into or closed.

A write, an edit, a shell command, a job's start, a message to another session, a queue write, a spawn and a stop of another bee, and typing into, opening, focusing or closing a pane ask y/n before they run, unless **-y** is given, and so does **read_file** of a path outside the working tree (a link out of it included). The rest run without asking. An ask shows the whole input, a control character as **^X**; on the full screen **y** runs it only once every row has been on the screen, and the arrows scroll it.

Given a *prompt*, bee runs one turn and exits, streaming the answer to standard output. With no prompt, it opens its full screen on a terminal and a **>** loop elsewhere, or on a terminal too with **--plain**.

The full screen is also a pane: **(bee-main ["--stage"])**, called from love, settles a session and answers it as a stage for a **mitty**, so **love inle** opens one beside its shells (**C-a b**). A stage that cannot start answers why as a string. Closing the pane ends the session's turn and leaves the hive.

The system prompt tells the model where it is:

- the date, the platform and, in a git repository, the branch, its status and recent commits;
- a briefing on love: the toolchain the binary carries, a primer on the language, and how to lay love's source and build it;
- its own session name, and how to reach other sessions;
- every merge queue under **refs/queue/**, as it stood at start (see THE MERGE QUEUE);
- the project's own instructions: from **/** down to the working directory, each directory's **AGENTS.md** and then its **CLAUDE.md**, both where both exist.

The settings are read from **~/.love/etc/bee.l**, one form per line: **(api anthropic)** or **(api openai)**, **(url** "...**)**, **(model** *name***)**, **(key-env** *var***)**, **(max-tokens** *n***)**, **(shell** *word* ...**)**, **(context** *n***)**, **(thinking off)** and **(avatar** *name***)**. A key goes out only over TLS, and only to a peer whose certificate this binary has verified. Plain HTTP reaches this machine alone, and not a port another login (uid 1000 and up) listens on. A tree's own **./.bee.l** travels with a clone, so it may set only **model**, **max-tokens**, **thinking**, **context** and **queue-watch** over them.

# AVATARS

The hello box shows an avatar: eight by eight pixels drawn as four rows of half-blocks, in 24-bit colour when **COLORTERM** is **truecolor** or **24bit** and the nearest of 256 otherwise. They are **bunny** (the default), **bee**, **baby**, **hare**, **honeybee**, **beeface**, and **moon**, drawn by **love pom** at start as the moon stands then (UTC). The accent -- the box's border, the title, the spinner, the session's name and the mail marker -- follows it: the colour most of its vivid pixels share, or most of all its pixels when none is vivid.

**/avatar**, on the full screen or at the **>** prompt, draws them all with their names; **/avatar** *name* wears one at once, and **love bee --avatar** \[*name*\] does the same from a shell. The choice is kept as **(avatar** *name***)** in **~/.love/etc/bee.l**, replacing any before it; a tree's **./.bee.l** cannot set it. An unknown name is refused with the list of known ones.

# SCREENSAVERS

When the full screen has had no key for **(screensaver-idle** *n***)** minutes (10 unless set, 0 for never; a fraction is allowed), it plays the saver **(screensaver** *name***)**, **pom** unless set. Both are settings of **~/.love/etc/bee.l** alone: a look is the person's, not the tree's, so **./.bee.l** cannot set them. The **>** loop and **--plain** have none.

Any key takes the saver down and lays the screen again as it was; that key goes nowhere else. A turn that is running goes on underneath it, and a message, a queue notice or a tool asking y/n leaves a small **✉** in its top right corner instead of waking it.

- **pom**: the moon at this hour's phase (UTC, as **love pom** reckons it), large and centred on half cells, over a few dozen stars that brighten and dim each on its own slow cycle, its phase and how much is lit under it.
- **slop**: the slop's skin from **love lore slop**, drifting, in its own gold and pink.
- **life**: Conway's game of life on a torus of half cells, each cell's green its age, sown again when it settles.
- **matrix**: green rain down the columns, each a drop of its own speed and length.

A saver redraws only the cells that changed, at 8 to 15 frames a second, and skips a frame it is late for. **love bee -s** *name* plays one on its own, with no session, until a key; **-s** alone lists them, and a name it does not know lists them on standard error and exits 2.

# SESSIONS AND MESSAGES

Every running bee is a *session* with a name. It is **BEE_NAME** when that is set and free; otherwise it is the last part of the working directory followed by two hex digits. Sessions find each other, and write to each other, through plain files under the *hive*: **BEE_HIVE** when set, else **~/.love/run/hive**. Anything that can write a file can take part: a shell, a script, or another kind of agent.

A session keeps one directory in the hive, its *cell*, *hive***/***name***/**:

**card**
:   Who the session is, one *key value* pair a line: **pid**, **cwd**, **branch**, **model**, **state** (**idle**, **busy** or **asking**) and **since** (epoch seconds). It is rewritten whole, through a rename, on every change of state.

**inbox/**
:   The messages sent to the session, one file each.

**read/**
:   The messages the session has taken, moved there from **inbox/**.

A *message* file is a header and a body. The header is *key value* lines, **from** *name* and **sent** *seconds* among them; a blank line ends it, and everything after the blank line is the text. To send, write the file as **inbox/.***id* and then rename it to **inbox/***id*. A reader ignores dot files, so it never sees a message half written. Messages are taken in the order their ids sort, so an id should begin with the time in milliseconds; bee's own are *ms***-***sender***-***hex*.

A session is live while its card's **pid** is. Whoever lists the hive removes a cell whose card names a dead pid, along with its messages. A cell without a card is still being made, and is left alone. A session removes its own cell when it exits.

Messages are delivered at two points. While a turn runs, whatever has arrived joins the next request, beside that request's tool results. On the full screen, an idle session checks its inbox about once a second, and a message starts a turn of its own. The model reads each message as **\<message from="***name***"\>** ... **\</message\>** inside a user turn, and is told that it comes from another agent and not from the user.

A session also watches the binary it runs. At start it notes the binary's size, modification time and inode, and at most every **BEE_SELF_WATCH** seconds (30) it looks again. When another build has been laid there, it says so once, as a message from **bee** (on the full screen, a note): bee was updated, when the new build was written, and to restart at the next convenient point, between tasks and never mid-gate, in the same directory. Until then the session goes on as it was. A bee's own **--mcp** child leaves this to the bee. The notice means the binary changed, not that bee's code did: any make that relinks a tree's **out/love** tells every session running that file.

The model's **list_sessions** tool reads the cards, and **send_message** writes a message as described above. From a shell, **love bee --list** prints the same list and **love bee --send** *name* *text* sends; the sender is **BEE_NAME**, else **cli-***user*.

# THE CLAUDE CODE BACKEND

With **(backend claude-code)** in the settings, bee is the harness and Claude Code does the work. Each bee session keeps one long-lived child:

> **claude -p --input-format stream-json --output-format stream-json --verbose --include-partial-messages --permission-prompt-tool mcp__bee__approve --mcp-config** *cell***/mcp.json --append-system-prompt** ... **--session-id** *uuid*

It uses Claude Code's own tools and its own login, so no key is set in bee. Each user turn goes to the child's stdin as one stream-json line. The child's lines come back and are drawn on the same screen:

- its streamed text and thinking as they arrive;
- its tool calls as tool blocks, each result under its block;
- the usage for the gauge, and its **result** line's cost, summed beside the gauge.

**(claude-model** *name***)** picks the child's model. The card records the model the child reports and its Claude session id. When the child ends or is interrupted with esc, the next turn starts it again with **--resume**.

The child reaches the bee and the hive through **love bee --mcp**, which its **mcp.json** names as the MCP server **bee**, speaking as the session **BEE_AS** names. **approve** is the child's permission prompt. It allows at once when the bee runs with **-y** (**BEE_YES**). Otherwise it writes **asks/***id***.ask** in the bee's cell, holding the tool's name, input and **tool_use_id**, and waits **BEE_ASK_WAIT** seconds (600) for **asks/***id***.answer**. It denies when no answer comes. The bee's screen turns each ask into the y/n of the tool's own block, and the key writes the answer.

# THE MCP SERVER

**love bee --mcp** is a stdio JSON-RPC 2.0 server, one message a line. It is how a Claude Code session takes part: as a bee's child, above, or on its own, from the project's **.mcp.json**, which in love's tree runs the tree's **out/love** when it is built and **love** on PATH otherwise. Both reach the hive by the one path. Its tools, which the model sees as **mcp__bee__***:

- **list_sessions**, **send_message**, the four queue tools and the three lock tools, the same as a bee agent's;
- **inbox**, which takes the messages waiting;
- **set_name**, which moves the session to a name of its choosing;
- **approve**, for a bee's child.

A session's *initialize* answer carries instructions: its name, how its mail arrives, and the merge queue's rules with the queues as they stood.

With **BEE_AS** set, the server speaks as that bee, which keeps the cell and watches the queues. Without it, the server is a session of its own:

- It settles in the hive while it runs, under **BEE_NAME** when that is free, else the working directory's last part, with two hex digits added only when that name is taken. A restart therefore keeps its name.
- Its card says **model claude-code**, and **love bee --list** shows it. It leaves the hive when its stdin ends.
- It watches the queues for its rows, as a bee does.

Mail and queue-watch notices wait in the inbox, and every tool's answer carries what has arrived, appended as **\<message from="***name***"\>** blocks, as a bee's next request carries it. A bee's child gets its mail the same way while a turn runs. Whoever takes a message moves it to **read/** first, so a bee and its server never both take one.

A session of its own also rings. Its server declares Claude Code's **claude/channel** capability, and once a second, when new mail has come, it sends one **notifications/claude/channel** notice naming who wrote: *n* **messages for** *name* **from** *senders***: take it with the inbox tool.** A notice starts a turn in an idle session, so the hive wakes itself and nobody has to be nagged. The notice is a bell, not the mail: the mail stays in the inbox for **inbox** or the next tool's answer. Claude Code hears a channel only from a session started with

> **claude --dangerously-load-development-channels server:bee**

and drops the notice in silence otherwise, which then costs nothing: that session gets its mail as before, on its next tool call. Start every Claude Code session in love's tree this way, a resume included. The restart notice above rings too, since it comes as mail. A bee's own child (**BEE_AS**) declares no channel; its bee hears the mail.

A session of its own also leaves its way back. Its server writes **.resume/***name* in the hive, holding Claude Code's session id (**CLAUDE_CODE_SESSION_ID**) and its directory; unlike the card, it outlives the session, and **set_name** moves it. **love bee --resume** lists the names it can bring back, and **love bee --resume** *name* [*prompt*] relaunches one: in its directory, as **BEE_NAME=***name*, with the channel flag, and with an MCP config that runs bee from the binary that ran **--resume**, so a worktree whose **out/love** predates the bell still rings. A live name is refused. **--cmd** prints the line instead of running it, for a script or a terminal multiplexer to run.

Asking stays with the caller. A bee's child asks through **approve**. A Claude Code session of its own asks through Claude Code's permission prompt, so the user says y before a message or a queue write goes out, unless that session runs without asking.

# LOCKS

The machine is shared, and **src/apps/locks.l** keeps its locks: an exclusive lock per resource, such as one make per **out/**, and a pool of heavy tickets, at most **(heavy-max** *n***)** at once (2 unless set) and none granted while available memory is below **(mem-floor** *gb***)**. A lock is held by a pid, so it lives as long as its holder. A bee holds its locks under its own pid, the one on its card, even when its **--mcp** child asks for them. That way a lock outlives a Claude child that ends and dies with the bee.

The model has **lock_acquire** (*name*, *kind* exclusive or heavy, *note*), **lock_release** and **lock_list**; the last two run without asking. An acquire answers at once: granted, or queued with its position, who holds it and how much memory is available. A queued lock is asked for again every 5 seconds, which keeps its place, and when it is granted a message from **lock-***name* says so. So a turn never waits on a lock. From a shell, **love bee --lock** waits for an exclusive lock on the command's **out/** (**./out** when there is one, or **--out** *dir*) and, with **--heavy**, for a heavy ticket. It then runs the command, releases both however the command ends, and exits with its status. A binary built without **src/apps/locks.l** says so.

# JOBS AND WORKERS

A *job* is a command line run in the background. **start_job** answers its id (**j1**, **j2** ...) at once and the turn goes on. The job runs in a process group of its own, with its output in *hive***/jobs/***name***/***id***.log**. When it ends, a message from **job-***id* reaches the bee that started it, carrying the exit status and the output's last lines. Like any message, it wakes an idle full screen and joins the next request of a running turn. **check_job** shows a job's state and output so far. **stop_job** ends its whole group: the shell and whatever it started. A job belongs to its bee's process: a one-shot **love bee** *prompt* exits when its turn does, and a job still running then goes on unwatched.

A *worker* is a bee started detached with **spawn_bee**, or **love bee --spawn** *name* *dir* *prompt*. It runs **love bee --serve** in *dir* under the session name *name*, with its output in *hive***/logs/***name***.log**. It takes *prompt* as its first turn, then settles and makes a turn of every message sent to it, until **stop_bee** or **love bee --stop** *name*. With no terminal it cannot answer an ask. It acts without asking only when it was spawned with **-y** (**spawn_bee** passes on the spawning session's **-y**); otherwise it can only read. Give each worker a working tree of its own, a git worktree or an sb nest, and tell it in its prompt whom to report to.

A child never inherits the bee's own open files: every fd above 2 is closed in it, so a job or a worker cannot hold a pipe open behind its parent's back.

# THE MERGE QUEUE

Sessions working in parallel often share one branch, the *base*, and merge into it one at a time through a *queue*. bee keeps one standard protocol for this, written here once. In love's tree, sessions take part in a queue only through bee's tools, from a bee agent or from Claude Code through **love bee --mcp**; nobody edits a queue by hand.

## The store

A queue is a text kept where it moves only by compare-and-swap. Either store will do; bee uses git when the directory is in a git repository, and sb otherwise.

**git**
:   Every ref under **refs/queue/**. The queue **refs/queue/***name* merges into the branch *name*. Read it with **git cat-file -p refs/queue/***name*; a write is **git hash-object -w** *file*, then **git update-ref refs/queue/***name* *new* *old*.

**sb**
:   Every ledger under **queue/** in the *hub*: the nest named by **SB_HUB**, else the working directory when it holds a **.sb/**. Read it with **sb -C** *hub* **ledger queue/***name*; a write is **sb -C** *hub* **ledger queue/***name* **--was** *old* *file*. A ledger keeps every entry it ever held, with its writer, under **--log**, and it never travels in **sync**, so sessions that share a queue name one hub.

## The text

A queue is lines:

- a header of **#** lines that states the rules;
- **leader** *session*, or **leader** *session* **acting**;
- the base line, *branch* *sha*, with an optional note after **#**;
- **next** *n*, the position the next join takes, so numbers never repeat;
- optionally **sync** *text*, what the queue lands toward, and **pre** *text* lines, conditions before that;
- a row per merge: *position* *session* *branch* *gated-on* *gated-head* *state*, with an optional note after two spaces and **#**.

*gated-on* is the base's sha for the head row, and the row above's *gated-head* for any other. *state* is **waiting**, **gating**, **green** or **folded-into-***N*. A field not known yet is **-**.

When a queue does not exist yet, **queue_row** makes it on bee's standard header. That header states every rule below in the queue itself, because a queue outlives the bee that made it. The leader is the session **queue_row** names in **leader**, else the maker. The base line is the branch the queue is named for, at its sha.

## The rules

**Join.** A session adds its row at the bottom when its branch is ready to gate. The order is fixed at join, never by who finishes a gate first.

**Stacked.** The head row gates its branch merged with the base. Row *k*+1 gates its branch merged with row *k*'s gated head, so when *k* lands the base already equals the tree *k*+1 certified, and *k*+1 lands without gating again. A failure, or a new head above, re-gates only the rows behind it.

**A row says what is true.** It is written **gating**, with its head, in one write before the gate starts. It is **green** only when every lane has passed on that head, and **waiting** only when nothing runs. Lanes follow the files touched, not the intent: a cross-cutting lane is where a union goes red, and the project's instructions may map files to lanes. The slow lane runs last, on the exact tree that lands.

**Land by sha.** The green head row lands its gated head with **git merge --no-ff** *sha*, and only when **git merge-tree --write-tree** of the base and *sha* gives *sha*'s own tree. After the landing, the base's first-parent line since the base line must hold a merge of *sha* with the gated tree. That merge, not the base's tip, is where the base line moves, so rows that land back to back are each recorded against their own merge. The lander then sends the next rows a *release note* naming what the merge removes, renames or moves. A session that cannot land (a sandbox that refuses the main checkout) hands the user the exact commands, with the shas and the tree each must print, so the landing can be checked without trusting it. It checks the checkout for someone's uncommitted edits first. On sb, the patch set that lands is exactly the set that was gated.

**The leader.** The **leader** line names the one session that keeps the queue. Only the leader edits another's row, the base line, and the **sync** and **pre** lines. The leader:

- writes a row for a session that cannot write its own;
- places a join by when it was asked for;
- drops a gone session's row and re-gates the rows behind it;
- corrects a row that no longer matches its branch;
- tells the sessions each such edit moves.

The leader hands off by rewriting the line to a live session that agreed, and says so to everyone. While the leader has no live session, the head row's session writes **leader** *itself* **acting**. The leader never lands, reorders or gates on another's behalf.

**Merge, not line up.** A waiting row folds into the earliest waiting row ahead of it, never into one that is gating, and a join while a row waits folds into that row. The leader writes **folded-into-***N* and tells both owners. The absorbing row merges every folded head onto its gated-on, gates the union of their lanes once, and lands one merge. A red in a folded branch's files goes to that branch's owner. A slow fix unfolds that branch so the rest can land. A merge-tree conflict between the heads goes to both owners with the hunk, and neither side is picked. That conflict, or an owner who objects, keeps the row its own slot, behind the fold. A re-cut row (a tree-wide rename) takes folds like any waiting row: its owner merges the join in the old layout, and the re-cut moves it.

**The long queue.** A queue is *long* when two or more rows are waiting or gating, or when more sessions wait for a heavy lock than there are slots. Then, without being asked:

- branches with one owner join as one union: each stops at its own light lanes, and the union gates once, the slow lane last;
- sessions with neighbouring work offer each other a fold, and the leader places it;
- a build seeds its **out/** from a built tree of its base with `cp -a`, which keeps file times -- never `cp -r`, which stamps every output newer than its sources so nothing rebuilds; when `cp -a` is refused, build clean;
- nothing holds a heavy slot it is not using.

**Say it, then verify it.** Tell the leader every change of state: join, gating, green, landed. The leader verifies from the store, not from the message. A restart may rename a session, which then asks the leader to correct its row and says so.

**Restart onto a new bee.** After a landing that changes bee (**src/apps/bee.l**, **locks.l**, **saver.l** or **pom.l**), every live session restarts at its next convenient point: between tasks, never mid-gate, resuming in the same directory so **.mcp.json** loads the new bee. **queue_landed** ends the release note with this, and each session's own watch on its binary says it too.

## The tools

Every tool reads the queue fresh and writes it by compare-and-swap, reading again when someone wrote first. The queue must be named **refs/queue/***name* or **queue/***name*. No field may hold a control character, and only a text field (a note, a sync or pre line, a release note) may hold a space, so one field cannot write another row. A tool that writes asks first, unless the session runs with **-y**.

**queue_row** (*queue*, *state*, and any of *branch*, *gated_on*, *gated_head*, *note*, *row*)
:   Sets exactly one of the caller's rows. A session holds a row per branch: the write sets the row **row** names, else the row carrying **branch**, else the caller's only row, and a **branch** it holds no row for joins a new one. A new row joins at the bottom, at the **next** line's position, and moves that line past it; a queue without the line starts one past the highest position and writes it. **left** removes the row. Fields not given keep their values. It refuses:

    - a state outside the list above;
    - a write that cannot say which row, from a session holding more than one, naming neither *row* nor *branch*;
    - a new *branch* written onto a row that is folded or gating (pass the branch alone, to join a new row);
    - a fold by anyone but the leader;
    - a fold into a row that is missing, not waiting, or not ahead;
    - a fold of a row that others fold into.

    Only the leader may pass **session** to edit another's row, **base** to move the base line, or **position** to place a new row at a number no row holds. **leader** names the leader of a queue being made. When the queue is long, the answer says so and tells the model to fold, not line up.

**queue_lead** (*queue*, and any of *leader*, *sync*, *pre_add*, *pre_drop*, *base*)
:   The leader's own lines, for the leader alone. **leader** hands the queue on. **base** moves the base line, touching no row. **sync** sets the sync line, and **-** removes it. **pre_add** adds a pre line, and **pre_drop** *n* drops the *n*th. The head row's session may pass itself as **leader** while the leader has no live session in the hive. That writes **leader** *itself* **acting**.

**queue_land** (*queue*)
:   Answers how to land the caller's row, on git, and changes nothing. The row must be green and at the head. The base branch must be where the base line says. **git merge-tree --write-tree** of the base and the gated head must give the gated tree. The answer is the checkout of the base, then **git rev-parse** of the base and the sha it must print, **git merge --no-ff** *sha*, and **git rev-parse 'HEAD^{tree}'** with the tree it must print.

**queue_landed** (*queue*, optionally *release*)
:   After the landing, it walks the base's first-parent history since the base line (**git log --first-parent** *line*..*base*), oldest first, for a commit with the gated tree that merges the gated head: the head is one of its other parents, or an ancestor of one. Failing that, it takes the base's tip when the tip holds the gated head and has the gated tree. Only then does it drop the row and the rows folded into it and move the base line to that commit, keeping the line's note; when there is none, the row stays and the answer says what was checked. A *release* note goes to the sessions of the next row and the rows folded into it, and the answer names each session it reached and each it could not, for the caller to relay. Without one, the answer names those sessions. When the landed range, from the base line's old sha to the landing, touches bee's served code, the note ends with the restart line, and goes out even without a *release*.

## Watching

bee quotes each queue in the system prompt as it stood at start, and tells the model to follow the rules and to read the queue fresh before acting on it. A session with rows watches the queues: a bee on its full screen or serving, and an MCP server of its own. It reads every queue again every **(queue-watch** *n***)** seconds (20 unless set, 0 for never), and a change that concerns its rows comes to it as a message from **queue-watch**:

- its own row leaving the queue;
- the row it stacks on (the nearest unfolded row above it) moving head or state, or leaving;
- a row folding into it, or a folded row moving;
- a new leader;
- the queue turning long.

The leader hears every row, with or without one of its own: each join, move and leaving. A session's own edits to its own rows say nothing.

# EXAMPLES

Ask one thing, and let it act without asking:

> ```
> love bee -y 'make the tests pass'
> ```

See who is running, and send one of them a note:

> ```
> love bee --list
> love bee --send g-3f 'row 62 landed; rebase onto gwen'
> ```

Send the same note with nothing but a shell:

> ```
> d=~/.love/run/hive/g-3f/inbox; id=$(date +%s)000-me
> printf 'from me\n\nrow 62 landed\n' > "$d/.$id" && mv "$d/.$id" "$d/$id"
> ```

# ENVIRONMENT

**BEE_NAME**
:   This session's name, and the sender that **--send** signs with.

**BEE_HIVE**
:   The hive's directory, **~/.love/run/hive** when unset.

**BEE_SELF_WATCH**
:   Seconds between looks at the binary this session runs, 30 when unset.

**SB_HUB**
:   The sb nest whose **queue/** ledgers are the merge queues.

**ANTHROPIC_API_KEY**, **OPENAI_API_KEY**
:   The key, by default; **(key-env** *var***)** names another.

# EXIT STATUS

**0** when the run ends normally. **1** when the settings name no usable endpoint, model or key, when a message cannot be delivered, or for an unknown **--avatar**. **2** for a malformed **--send**, or a screensaver **-s** does not know.

# SEE ALSO

**love**(1), **lush**(1), **cook**(1)
