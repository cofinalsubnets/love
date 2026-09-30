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

# DESCRIPTION

**bee** puts a model to work in the current directory. The model's tools:

- **read_file**, **write_file** and **edit_file**;
- **shell**, which runs a command line in **lush -a** (this binary's shell, with love's own verbs ahead of PATH);
- **list_sessions** and **send_message**, described under SESSIONS AND MESSAGES;
- **start_job**, **check_job** and **stop_job**, and **spawn_bee** and **stop_bee**, described under JOBS AND WORKERS.

A write, an edit, a shell command, a job's start, a queue row, a spawn and a stop of another bee ask y/n before they run, unless **-y** is given. The rest run without asking.

Given a *prompt*, bee runs one turn and exits, streaming the answer to standard output. With no prompt, it opens its full screen on a terminal and a **>** loop elsewhere, or on a terminal too with **--plain**.

The system prompt tells the model where it is:

- the date, the platform and, in a git repository, the branch, its status and recent commits;
- a briefing on love: the toolchain the binary carries, a primer on the language, and how to lay love's source and build it;
- its own session name, and how to reach other sessions;
- every merge queue under **refs/queue/**, as it stood at start (see THE MERGE QUEUE);
- the project's own instructions: from **/** down to the working directory, each directory's **AGENTS.md** and then its **CLAUDE.md**, both where both exist.

The settings are read from **~/.love/etc/bee.l**, one form per line: **(api anthropic)** or **(api openai)**, **(url** "...**)**, **(model** *name***)**, **(key-env** *var***)**, **(max-tokens** *n***)**, **(shell** *word* ...**)**, **(context** *n***)** and **(thinking off)**. A key goes out only over TLS, and only to a peer whose certificate this binary has verified. Plain HTTP reaches this machine alone. A tree's own **./.bee.l** travels with a clone, so it may set only **model**, **max-tokens**, **thinking**, **context** and **queue-watch** over them.

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

# THE CLAUDE CODE BACKEND

With **(backend claude-code)** in the settings, bee is the harness and Claude Code does the work. Each bee session keeps one long-lived child:

> **claude -p --input-format stream-json --output-format stream-json --verbose --include-partial-messages --permission-prompt-tool mcp__bee__approve --mcp-config** *cell***/mcp.json --append-system-prompt** ... **--session-id** *uuid*

It uses Claude Code's own tools and its own login, so no key is set in bee. Each user turn goes to the child's stdin as one stream-json line. The child's lines come back and are drawn on the same screen:

- its streamed text and thinking as they arrive;
- its tool calls as tool blocks, each result under its block;
- the usage for the gauge, and its **result** line's cost, summed beside the gauge.

**(claude-model** *name***)** picks the child's model. The card records the model the child reports and its Claude session id. When the child ends or is interrupted with esc, the next turn starts it again with **--resume**.

The child reaches the bee and the hive through **love bee --mcp**, which its **mcp.json** names as the MCP server **bee**. That is a stdio JSON-RPC 2.0 server, one message a line, speaking as the session **BEE_AS** names. Its tools are **list_sessions**, **send_message** and **queue_row**, which the model sees as **mcp__bee__***, and **approve**, the child's permission prompt. **approve** allows at once when the bee runs with **-y** (**BEE_YES**). Otherwise it writes **asks/***id***.ask** in the bee's cell, holding the tool's name, input and **tool_use_id**, and waits **BEE_ASK_WAIT** seconds (600) for **asks/***id***.answer**. It denies when no answer comes. The bee's screen turns each ask into the y/n of the tool's own block, and the key writes the answer.

# LOCKS

The machine is shared, and **src/apps/locks.l** keeps its locks: an exclusive lock per resource, such as one make per **out/**, and a pool of heavy tickets, at most **(heavy-max** *n***)** at once (2 unless set) and none granted while available memory is below **(mem-floor** *gb***)**. A lock is held by a pid, so it lives as long as its holder. A bee holds its locks under its own pid, the one on its card, even when its **--mcp** child asks for them. That way a lock outlives a Claude child that ends and dies with the bee.

The model has **lock_acquire** (*name*, *kind* exclusive or heavy, *note*), **lock_release** and **lock_list**; the last two run without asking. An acquire answers at once: granted, or queued with its position, who holds it and how much memory is available. A queued lock is asked for again every 5 seconds, which keeps its place, and when it is granted a message from **lock-***name* says so. So a turn never waits on a lock. From a shell, **love bee --lock** waits for an exclusive lock on the command's **out/** (**./out** when there is one, or **--out** *dir*) and, with **--heavy**, for a heavy ticket. It then runs the command, releases both however the command ends, and exits with its status. A binary built without **src/apps/locks.l** says so.

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

bee quotes each queue in the system prompt as it stood at start, and tells the model to follow the rules and to read the queue fresh before acting on it. A row names its session. The model reaches a bee session with **send_message**, and asks the user to relay to any other.

The model writes a queue only through **queue_row**, never by hand; a small model given the text to edit once replaced a whole queue with its one row. The tool reads the queue and changes exactly one line: the bee's own row, keyed by its session name, in the header's format *position session branch gated-on gated-head state*, with an optional note after **#**. The model gives the state (**waiting**, **gating**, **green**, **folded-into-***N*, or **left**, which removes the row) and whichever other fields change, and the rest keep their values. A bee with no row joins at the bottom, one past the highest position. The write is a compare-and-swap, retried from a fresh read when someone wrote first. Only the bee named on the **leader** line may pass **session** to edit another's row, or **base** to move the base line (*branch* *sha*) when it lands; anyone else is refused. The queue must be **refs/queue/***name* or **queue/***name*, and no field may hold a control character, nor any but the note a space, so one field cannot write another row.

A bee watches the queues for its rows. On the full screen and when serving, it reads every queue again every **(queue-watch** *n***)** seconds (20 unless set, 0 for never). A change that concerns its rows comes to it as a message from **queue-watch**:

- its own row leaving the queue;
- the row it stacks on (the nearest unfolded row above it) moving head or state, or leaving;
- a row folding into it, or a folded row moving;
- a new leader.

The leader hears every row, with or without one of its own: each join, move and leaving. Its own edits to its own rows say nothing.

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
