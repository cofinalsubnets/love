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

# DESCRIPTION

**bee** puts a model to work in the current directory. The model's tools:

- **read_file**, **write_file** and **edit_file**;
- **shell**, which runs a command line in **lush -a** (this binary's shell, with love's own verbs ahead of PATH);
- **list_sessions** and **send_message**, described under SESSIONS AND MESSAGES;
- **start_job**, **check_job** and **stop_job**, and **spawn_bee** and **stop_bee**, described under JOBS AND WORKERS.

A write, an edit, a shell command, a job's start, a spawn and a stop of another bee ask y/n before they run, unless **-y** is given. The rest run without asking.

Given a *prompt*, bee runs one turn and exits, streaming the answer to standard output. With no prompt, it opens its full screen on a terminal and a **>** loop elsewhere, or on a terminal too with **--plain**.

The system prompt tells the model where it is:

- the date, the platform and, in a git repository, the branch, its status and recent commits;
- a briefing on love: the toolchain the binary carries, a primer on the language, and how to lay love's source and build it;
- its own session name, and how to reach other sessions;
- every merge queue under **refs/queue/**, as it stood at start (see THE MERGE QUEUE);
- the project's own instructions: from **/** down to the working directory, each directory's **AGENTS.md** and then its **CLAUDE.md**, both where both exist.

The settings are read from **~/.love/etc/bee.l** and then **./.bee.l**, one form per line: **(api anthropic)** or **(api openai)**, **(url** "...**)**, **(model** *name***)**, **(key-env** *var***)**, **(max-tokens** *n***)**, **(shell** *word* ...**)**, **(context** *n***)** and **(thinking off)**. A key goes out only over TLS, and only to a peer whose certificate this binary has verified. Plain HTTP reaches this machine alone.

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

The model's **list_sessions** tool reads the cards, and **send_message** writes a message as described above. From a shell, **love bee --list** prints the same list and **love bee --send** *name* *text* sends; the sender is **BEE_NAME**, else **cli-***user*.

# JOBS AND WORKERS

A *job* is a command line run in the background. **start_job** answers its id (**j1**, **j2** ...) at once and the turn goes on. The job runs in a process group of its own, with its output in *hive***/jobs/***name***/***id***.log**. When it ends, a message from **job-***id* reaches the bee that started it, carrying the exit status and the output's last lines. Like any message, it wakes an idle full screen and joins the next request of a running turn. **check_job** shows a job's state and output so far. **stop_job** ends its whole group: the shell and whatever it started. A job belongs to its bee's process: a one-shot **love bee** *prompt* exits when its turn does, and a job still running then goes on unwatched.

A *worker* is a bee started detached with **spawn_bee**, or **love bee --spawn** *name* *dir* *prompt*. It runs **love bee --serve** in *dir* under the session name *name*, with its output in *hive***/logs/***name***.log**. It takes *prompt* as its first turn, then settles and makes a turn of every message sent to it, until **stop_bee** or **love bee --stop** *name*. With no terminal it cannot answer an ask. It acts without asking only when it was spawned with **-y** (**spawn_bee** passes on the spawning session's **-y**); otherwise it can only read. Give each worker a working tree of its own, a git worktree or an sb nest, and tell it in its prompt whom to report to.

A child never inherits the bee's own open files: every fd above 2 is closed in it, so a job or a worker cannot hold a pipe open behind its parent's back.

# THE MERGE QUEUE

Sessions working in parallel often share one branch, and merge into it one at a time. bee does not impose a protocol for this: it reads one out of the version control. A *queue* is a text whose header states its rules, names its leader, and holds a row per merge, kept where it can move only by compare-and-swap. Either store will do:

**git**
:   Every ref under **refs/queue/**. Read it with **git cat-file -p refs/queue/***name*, and take the ref's sha as *old*. Write **git hash-object -w** *file*, then **git update-ref refs/queue/***name* *new* *old*.

**sb**
:   Every ledger under **queue/** in the *hub*: the nest named by **SB_HUB**, else the working directory when it holds a **.sb/**. Read it with **sb -C** *hub* **ledger queue/***name*, and take **--id** as *old*. Write **sb -C** *hub* **ledger queue/***name* **--was** *old* *file*. A ledger keeps every entry it ever held, with its writer, under **--log**, and it never travels in **sync**: sessions that share a queue name one hub.

bee quotes each queue in the system prompt as it stood at start, and tells the model to follow the rules, to read the queue fresh before acting on it, and to write only its own row. When a write fails, someone wrote first: re-read and redo. A row names its session. The model reaches a bee session with **send_message**, and asks the user to relay to any other.

A bee watches the queues for its rows. On the full screen and when serving, it reads every queue again every **(queue-watch** *n***)** seconds (20 unless set, 0 for never). A change that concerns its rows comes to it as a message from **queue-watch**:

- its own row leaving the queue;
- the row it stacks on (the nearest unfolded row above it) moving head or state, or leaving;
- a row folding into it, or a folded row moving;
- a new leader.

Its own edits to its own rows say nothing.

The model is also given the queue's operating checks, learned running one. Each is meant to be checked mechanically, not just stated:

- **The landed tree is the gated tree.** Before a landing, **git merge-tree --write-tree** *branch* *head* must print the gated head's own tree, and afterwards *branch***^{tree}** must equal it. On sb, the patch set that lands is exactly the set that was gated.
- **Stacked.** A row gates its branch merged with the gated head of the row above. When that head moves, every row above it re-merges and re-gates.
- **The row says what is true.** It is written **gating** together with the head being gated before the gate starts, **green** only when every lane has passed, and **waiting** only when nothing runs. A waiting row takes folds; a gating one cannot.
- **Lanes follow the files touched**, not the intent. A cross-cutting lane is where a union goes red, and the project's own instructions may map files to lanes. The slow lane runs last, on the exact tree that lands.
- **A fold conflict** goes to both owners with the hunk, and neither side is picked. A red in a folded branch's files belongs to its owner, and a slow fix unfolds that branch so the rest can land.
- **A session that cannot land** (a sandbox that refuses the main checkout) hands the user the exact commands, with the expected base sha and tree hash, so the landing can be checked without trusting it. It checks the checkout for someone else's uncommitted edits first.
- **The leader hears every change of state**: join, gating, green, landed. It verifies from the store, not from the message. A restart may rename a session, which then fixes its row and says so.

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

**SB_HUB**
:   The sb nest whose **queue/** ledgers are the merge queues.

**ANTHROPIC_API_KEY**, **OPENAI_API_KEY**
:   The key, by default; **(key-env** *var***)** names another.

# EXIT STATUS

**0** when the run ends normally. **1** when the settings name no usable endpoint, model or key, or when a message cannot be delivered. **2** for a malformed **--send**.

# SEE ALSO

**love**(1), **lush**(1), **cook**(1)
