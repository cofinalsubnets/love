---
title: BEE
section: 1
source: love @VERSION@
manual: love manual
---

# NAME

bee - the hive of sessions on this machine, and the merge queue they land through

# SYNOPSIS

**love bee** \| **--hud**

**love bee --list**

**love bee --send** *name* *text* ...

**love bee --resume** \[*name* \[*prompt* ...\]\]

**love bee --mcp**

**love bee --state busy** \| **idle** \[**--pid** *pid*\]

**love bee --lock** \[**--heavy** \[**--no-row** *reason*\]\] \[**--out** *dir*\] **--** *command* ...

**love bee --on** *cap* \[**--where** *key***=***value*\] \[**--ship** *dir*\] **--probe** \| **--ssh** \| **--** *command* ...

**love bee --hosts**

**love bee --lanes-doc** \| **--lanes-map**

**love bee --lanes** \[*base* \[*head*\]\]

**love bee --gate** *queue*

# DESCRIPTION

**bee** is how the coding sessions on one machine find each other, write to each other, share its locks and land their work one merge at a time. A session is a Claude Code session, which takes part through **love bee --mcp** (THE MCP SERVER); anything else that can write a file can join the hive by hand (SESSIONS AND MESSAGES).

On a terminal, **love bee** shows the *hud*, which needs no session of its own. It shows each merge queue: the base line, the leader and the sync line, with when the next publish is due (the last publish the sync line names, plus 8 hours; yellow within the hour, red once past); then every row (position, session, branch, gated-on, head and state), what it carries (its note's first clause), and how long it has held its state, a folded row dim and indented under the row it joins, the head row bright, and a stall (WATCHING) in red under its row; and a note when the queue is long. Each session keeps one colour wherever it appears; shas are dim. How long a row has held its state is first-seen time, kept in the hive (**.seen/**) by every watching session and the hud; no row carries a time. Below the queues are the locks (the heavy tickets against **(heavy-max** *n***)**, the waiters, the **out/** locks and the hosts' **host-** slots, memory and load) and the sessions: each one's state and how long it has held it, **background** for a backgrounded Claude Code session, and the time since its last bee tool call. It reads them all again every **(queue-watch** *n***)** seconds, 20 unless set, and on **r**. **q** quits; the arrows, **j** and **k** scroll. **--hud** prints it once, as text.

While it is open, the hud holds the *user's card*, at the login's name (**USER**), and the user talks to the hive through it. **c** or Enter opens a line to a session, the first queue's leader at first: Enter sends what is typed, Tab names the next session, and Esc goes back to looking. The talk shows under the queues, with whatever comes back to the user's name. A second hud for one login has no card, and only looks.

The hud is drawn by **src/apps/mitty/hud.l**. It reaches the hive through bee's *core*, a tablet of doors (**bee-core** in **src/apps/bee.l**): the user's card and its mail, the sessions, and the queues' lines.

The settings are read from **~/.love/etc/bee.l**, one form per line: **(heavy-max** *n***)**, **(mem-floor** *gb***)**, **(queue-watch** *n***)**, **(gone-minutes** *n***)** and **(stall-minutes** *n***)**. A tree's own **./.bee.l** travels with a clone, so it may set only **queue-watch**, **gone-minutes** and **stall-minutes** over them.

# SESSIONS AND MESSAGES

Every session has a name. It is **BEE_NAME** when that is set and free; otherwise it is the last part of the working directory followed by two hex digits. Sessions find each other, and write to each other, through plain files under the *hive*: **BEE_HIVE** when set, else **~/.love/run/hive**. Anything that can write a file can take part: a shell, a script, or another kind of agent.

A session keeps one directory in the hive, its *cell*, *hive***/***name***/**:

**card**
:   Who the session is, one *key value* pair a line: **pid**, **cwd**, **branch**, **model**, **state** (**idle** or **busy**) and **since** (epoch seconds), and for a Claude Code session **turn**, when its state last moved, and **parent**, the pid of the Claude Code it serves. It is rewritten whole, through a rename, on every change of state.

**inbox/**
:   The messages sent to the session, one file each.

**read/**
:   The messages the session has taken, moved there from **inbox/**.

The reading of cells and cards that every client shares (**mitty**'s bar counts the live sessions with it) is the module **hive**, **src/apps/hive.l**.

A *message* file is a header and a body. The header is *key value* lines, **from** *name* and **sent** *seconds* among them; a blank line ends it, and everything after the blank line is the text. To send, write the file as **inbox/.***id* and then rename it to **inbox/***id*. A reader ignores dot files, so it never sees a message half written. Messages are taken in the order their ids sort, so an id should begin with the time in milliseconds; bee's own are *ms***-***sender***-***hex*.

A session is live while its card's **pid** is. Whoever lists the hive removes a cell whose card names a dead pid, along with its messages. A cell without a card is still being made, and is left alone. A session removes its own cell when it exits.

A *user's card* is the person at a login, in the hive through the hud. It says **kind user** and **model user**, its name is the login's, and its **state** is **here** while a hud holds it (its pid the hud's) and **away** after. It is never removed, so mail to the user waits in its inbox until a hud opens. One login has one, no agent may settle or be named as it, and **love bee --list** shows it as **user**. A message the hud sends says **kind user** in its header.

A session takes its messages with **inbox**, and every tool's answer carries whatever has arrived (THE MCP SERVER). The model reads each message as **\<message from="***name***"\>** ... **\</message\>**, and is told that it comes from another agent and not from the user. A message that says **kind user** from a user's card reads as **\<message from="***name***" kind="user"\>**, and the model is told that it is the user, typing into the hud at this machine under the same login, to be taken as the user's own words and answered with **send_message** to that name. The login is the boundary of trust here: the hive is files any process of that uid can write, and the user's name is reserved against accidents, not against that uid.

A session also watches the binary it runs. At start it notes the binary's size, modification time and inode, and at most every **BEE_SELF_WATCH** seconds (30) it looks again. When another build has been laid there and the bee source it carries (its **/love/src**: bee.l and the files bee runs) differs from this session's, it says so once, as a message from **bee**: bee was updated, when the new build was written, and to restart at the next convenient point, between tasks and never mid-gate, in the same directory. Until then the session goes on as it was. A relink that carries the same bee, as most makes are, tells nothing.

The **list_sessions** tool reads the cards, and **send_message** writes a message as described above. From a shell, **love bee --list** prints the same list and **love bee --send** *name* *text* sends; the sender is **BEE_NAME**, else **cli-***user*.

# THE MCP SERVER

**love bee --mcp** is a stdio JSON-RPC 2.0 server, one message a line. It is how a Claude Code session takes part, from the project's **.mcp.json**, which in love's tree runs the tree's **out/love** when it is built and **love** on PATH otherwise. Its tools, which the model sees as **mcp__bee__***:

- **list_sessions** and **send_message** (SESSIONS AND MESSAGES);
- **lock_acquire**, **lock_release** and **lock_list** (LOCKS), and **lanes**, after them;
- **queue_read**, **queue_row**, **queue_lead**, **queue_gate**, **queue_land** and **queue_landed** (THE MERGE QUEUE);
- **inbox**, which takes the messages waiting;
- **set_name**, which moves the session to a name of its choosing.

A session's *initialize* answer carries instructions: its name, how its mail arrives, and the merge queue's rules with the queues as they stood.

The server is a session of its own:

- It settles in the hive while it runs, under **BEE_NAME** when that is free, else the working directory's last part, with two hex digits added only when that name is taken. A restart therefore keeps its name.
- Its card says **model claude-code**, and **love bee --list** shows it. It leaves the hive when its stdin ends.
- Its state is its Claude Code's turns, which the server cannot see. Love's tree carries **.claude/settings.json**, whose hooks run **love bee --state busy** when a prompt is submitted and **--state idle** when the turn stops, each with **--pid** of the Claude Code that ran it, in the background and quietly. They add **--hud**, which **--state** ignores, so a bee too old to know **--state** prints its hud and does nothing else. **--state** finds the session whose card's **parent** is that pid or one of its parents, else **BEE_NAME**'s, else the one Claude Code session in its directory, and moves the card's **state** and **turn**. Each tool call also touches *cell***/seen**, so the hud can say how long a session has been quiet even without the hooks.
- It watches the queues for its rows (Watching).

Mail and queue-watch notices wait in the inbox, and every tool's answer carries what has arrived, appended as **\<message from="***name***"\>** blocks. Whoever takes a message moves it to **read/** first, so no two readers take one.

The server also rings. It declares Claude Code's **claude/channel** capability, and once a second, when new mail has come, it sends one **notifications/claude/channel** notice naming who wrote: *n* **messages for** *name* **from** *senders***: take it with the inbox tool.** A notice starts a turn in an idle session, so the hive wakes itself and nobody has to be nagged. The notice is a bell, not the mail: the mail stays in the inbox for **inbox** or the next tool's answer. Claude Code hears a channel only from a session started with

> **claude --dangerously-load-development-channels server:bee**

and drops the notice in silence otherwise, which then costs nothing: that session gets its mail as before, on its next tool call. Start every Claude Code session in love's tree this way, a resume included. The restart notice above rings too, since it comes as mail.

The server also leaves its way back. It writes **.resume/***name* in the hive, holding Claude Code's session id (**CLAUDE_CODE_SESSION_ID**) and its directory; unlike the card, it outlives the session, and **set_name** moves it. **love bee --resume** lists the names it can bring back, and **love bee --resume** *name* [*prompt*] relaunches one: in its directory, as **BEE_NAME=***name*, with the channel flag, and with an MCP config that runs bee from the binary that ran **--resume**, so a worktree whose **out/love** predates the bell still rings. A live name is refused, unless what keeps it live is a backgrounded Claude Code session (an **/exit** with work still running, or **claude --bg**: its claude runs under **claude --bg-pty-host**, with no terminal). Then **--resume** says so, with the session's short id: **--attach** runs **claude attach** *id* here, **--stop** runs **claude stop** *id* and resumes once the card is gone, and on a terminal it asks which. **--cmd** prints the line instead of running it, for a script or a terminal multiplexer to run.

Asking stays with Claude Code: its permission prompt asks before a message or a queue write goes out, unless that session runs without asking.

# LOCKS

The machine is shared, and **src/apps/locks.l** keeps its locks: an exclusive lock per resource, such as one make per **out/**, and a pool of heavy tickets, at most **(heavy-max** *n***)** at once (2 unless set) and none granted while available memory is below **(mem-floor** *gb***)**. A lock is held by a pid, so it lives as long as its holder. A session's locks are held under its server's pid, the one on its card.

A session has **lock_acquire** (*name*, *kind* exclusive or heavy, *note*, *no_row*), **lock_release** and **lock_list**. An acquire answers at once: granted, or queued with its position, who holds it and how much memory is available. A queued lock is asked for again every 5 seconds, which keeps its place, and when it is granted a message from **lock-***name* says so. So a turn never waits on a lock. From a shell, **love bee --lock** waits for an exclusive lock on the command's **out/** (**./out** when there is one, or **--out** *dir*) and, with **--heavy**, for a heavy ticket. It then runs the command, releases both however the command ends, and exits with its status. A binary built without **src/apps/locks.l** says so.

A heavy ticket belongs to a queue row. In a git work tree that has queues under **refs/queue/**, **--heavy** asks at the tree's top: the directory above **--out**'s, or the working directory. It is refused, naming the rule, while no row carries the tree's branch or its HEAD. A gate writes its row **gating** with that head first, so the head then matches. **--no-row** *reason* (the tool's *no_row*) passes, and the reason rides the lock's note, where **lock_list** shows it. Fair reasons are the leader's own work, a measurement gwen asked for, and a clean build before a join. A directory below a tree's top, such as scratch under **out/**, is not asked, and neither is a tree with no queue.

Which lanes a change owes is data, **src/apps/lanemap.l**: path rules, each naming the lanes owed by a change that touches its paths, the heavy lanes, and the chains and alone set that **test/gate/lanes.sh** runs lanes by. **love bee --lanes-doc** prints AGENTS.md's table, which is laid from it, and test/host/bee.l fails when the two disagree. **--lanes-map** prints lanes.sh's chains and alone set.

**love bee --lanes** and the **lanes** tool (*branch*, *base*) answer the lanes a change owes, in the order to run them. The change is *head*'s (HEAD unless given) against *base*, or, unless given, against where *head* left the branch of the one queue here. Its paths come from **git diff --name-only**. A rule owes its lanes to every path it matches. A lane that another owed lane runs is left out: its prerequisites and its recipe's **$(MAKE)** lines, read from **make -pq**. The light lanes come first, then the heavy ones, each cheapest first. **test** always heads the list and **test_slow** always closes it. Each line is the lane, **light** or **heavy**, its wall seconds on a shared box (**?** when unmeasured) and the paths that owed it.

# HOSTS

Work this box cannot do, or should not, runs on another: an a64 binary on an arm box, a kernel under kvm, a test on a BSD guest. The hosts a session may use are a registry, **~/.love/etc/bee/hosts** (**BEE_HOSTS** names another file), kept by **src/apps/hosts.l**. It holds a paragraph a host, each a run of *key value* lines like a card's, with a blank line between and **#** lines left out:

**name**
:   The host's name, which its locks carry.

**reach**
:   The words of the ssh that reaches it, **ssh** *name* unless given. bee adds batch mode and a short connect timeout just before the last word, so an option given here comes first and stands.

**slots**
:   How many pieces of work it takes at once, 1 unless given. Each slot is an exclusive lock, **host-***name***-***n*, so two lanes never crowd one box.

**caps**
:   What it can do, as words: **a64-exec** (runs linux/arm64 binaries), **kvm-a64** (boots an a64 guest under kvm), **vt-x** (boots an x64 guest that uses VT-x), **freebsd-x64**, **netbsd-x64**, **freebsd-a64**, **netbsd-a64**, **freebsd-rv64**, **netbsd-rv64** (that system, to test against).

Any other line is a *fact*, such as **isa**, **os** or **page** (its page size in bytes). For example:

```
# a pi 5 on the network, a 16K-page kernel
name arm1.lan
slots 3
caps a64-exec kvm-a64
page 16384

name bsd-guest
reach ssh -p 2222 root@127.0.0.1
caps freebsd-x64
```

**love bee --on** *cap* \[**--where** *key***=***value*\] \[**--ship** *dir*\] **--** *command* ... picks a host with *cap* that answers ssh, and whose fact *key* is *value* when **--where** asks; a **page** the registry does not give is asked of the host. It waits for a free slot on one, lays *dir*'s files in a scratch directory there in one tar over the one ssh, runs *command* in it with only **PATH**, **HOME** and **LANG=C**, removes the directory, frees the slot, and exits with the command's status. Its output comes back on this side's. **--probe** in place of the command exits 0 when such a host answers and 75 when none does; **--ssh** prints the words that reach it. **love bee --hosts** lists the registry.

The lanes ask for hosts this way: the a64 kernel lane boots on a **kvm-a64** host, the a64 lanes' binaries run on an **a64-exec** one, **test_kernel_vmx** boots on **vt-x**, and the BSD lanes find their boxes by their caps. A lane with a fallback takes 75 as its cue; one without skips loudly, which a strict box makes red. For one release the environment still names hosts, and a cap it names takes its hosts over the registry's: **KTEST_A64_HOSTS** (*host***:***slots* ...) for **a64-exec** and **kvm-a64**, **KTEST_VMX_HOSTS** for **vt-x**, and **FBSD_SSH**, **NBSD_SSH**, **FBSD_ARM64_SSH** and **NBSD_ARM64_SSH** (an ssh prefix each) for the four systems.

# THE MERGE QUEUE

Sessions working in parallel often share one branch, the *base*, and merge into it one at a time through a *queue*. bee keeps one standard protocol for this, written here once. In love's tree, sessions take part in a queue only through bee's tools, from Claude Code through **love bee --mcp**; nobody edits a queue by hand.

## The store

A queue is a text kept where it moves only by compare-and-swap: a git ref under **refs/queue/**. The queue **refs/queue/***name* merges into the branch *name*. Read it with **git cat-file -p refs/queue/***name*; a write is **git hash-object -w** *file*, then **git update-ref refs/queue/***name* *new* *old*.

## The text

A queue is lines:

- a header of **#** lines that states the rules;
- **leader** *session*, or **leader** *session* **acting**;
- the base line, *branch* *sha*, with an optional note after **#**;
- **next** *n*, the position the next join takes, so numbers never repeat;
- optionally **sync** *text*, what the queue lands toward, and **pre** *text* lines, conditions before that;

- optionally **keep** *position* ..., the rows that keep their own slot (**queue_row** *keep*);

- a row per merge: *position* *session* *branch* *gated-on* *gated-head* *state*, with an optional note after two spaces and **#**.

*gated-on* is the base's sha for the head row, and the row above's *gated-head* for any other. *state* is **waiting**, **gating**, **green** or **folded-into-***N*. A field not known yet is **-**.

When a queue does not exist yet, **queue_row** makes it on bee's standard header. That header states every rule below in the queue itself, because a queue outlives the bee that made it. The leader is the session **queue_row** names in **leader**, else the maker. The base line is the branch the queue is named for, at its sha.

## The rules

**Join.** A session adds its row at the bottom, **waiting**, once its branch builds and passes **make test** and the laws it adds. It runs none of its other lanes first: those, light and heavy (**love bee --lanes**), run only in the queue, once for a union, at its head. The order is fixed at join, never by who finishes a gate first.

**Stacked.** The head row gates its branch merged with the base. Row *k*+1 gates its branch merged with row *k*'s gated head, so when *k* lands the base already equals the tree *k*+1 certified, and *k*+1 lands without gating again. A failure, or a new head above, re-gates only the rows behind it.

**A row says what is true.** It is written **gating**, with its head, in one write before the gate starts. It is **green** only when every lane has passed on that head, and **waiting** only when nothing runs. Lanes follow the files touched, not the intent: a cross-cutting lane is where a union goes red, and the project's instructions may map files to lanes. The slow lane runs last, on the exact tree that lands.

**Land by sha.** The green head row lands its gated head with **git merge --no-ff** *sha*, and only when **git merge-tree --write-tree** of the base and *sha* gives *sha*'s own tree. After the landing, the base's first-parent line since the base line must hold a merge of *sha* with the gated tree. That merge, not the base's tip, is where the base line moves, so rows that land back to back are each recorded against their own merge. The lander then sends the next rows a *release note* naming what the merge removes, renames or moves. A session that cannot land (a sandbox that refuses the main checkout) hands the user the exact commands, with the shas and the tree each must print, so the landing can be checked without trusting it. It checks the checkout for someone's uncommitted edits first.

**The leader.** The **leader** line names the one session that keeps the queue. Only the leader edits another's row, the base line, and the **sync** and **pre** lines. The leader:

- writes a row for a session that cannot write its own;
- places a join by when it was asked for;
- drops a gone session's row and re-gates the rows behind it;
- corrects a row that no longer matches its branch;
- tells the sessions each such edit moves.

The leader hands off by rewriting the line to a live session that agreed, and says so to everyone. While the leader has no live session, the head row's session writes **leader** *itself* **acting**. The leader never lands, reorders or gates on another's behalf.

**Merge, not line up.** Waiting rows fold into one union. A join folds into the earliest waiting row ahead of it, never into one that is gating. bee writes the fold itself when the join is waiting with its head. The joining head must merge clean with the absorbing row's head and with each head already folded into it, except in the paths a union lays again (**src/tools/hot.prof**). bee then tells both owners. Otherwise the leader writes **folded-into-***N* and tells them. The absorbing row's owner merges each folded head onto its gated-on as it folds, and runs every lane its branches owe (the union of their **love bee --lanes**), light and heavy, once on that merged tree, the slow lane last (**queue_gate**). It then lands one merge. A red lane goes to the branches whose files owe it (**src/apps/lanemap.l**): those split out and go back to their owners, only the red lanes run again on the union without them, and the green lanes stand. The slow lane always runs again, on the exact tree that lands. A merge-tree conflict between the heads goes to both owners with the hunk, and neither side is picked. That conflict, or a row passed **keep 1**, keeps its own slot, behind the fold. A publish row folds into the waiting union and gates with it once. **test_gcstress** then runs in the background after the push. A re-cut row (a tree-wide rename) takes folds like any waiting row: its owner merges the join in the old layout, and the re-cut moves it.

**The long queue.** A queue is *long* when two or more rows are waiting or gating, or when more sessions wait for a heavy lock than there are slots. Then, without being asked:

- branches with one owner join as one union: each joins on **make test** and its own laws, and the union gates once, the slow lane last;
- no lane past those runs per branch: each runs once, in the union at the queue's head;
- sessions with neighbouring work offer each other a fold, and the leader places it;
- a build seeds its **out/** from a built tree of its base with `cp -a`, which keeps file times -- never `cp -r`, which stamps every output newer than its sources so nothing rebuilds; when `cp -a` is refused, build clean;
- nothing holds a heavy slot it is not using.

**Say it, then verify it.** Tell the leader every change of state: join, gating, green, landed. The leader verifies from the store, not from the message. A restart may rename a session, which then asks the leader to correct its row and says so.

**The owner lands.** The session whose row is green lands it, and then calls **queue_landed** with a release note; the leader lands only its own rows. Every sha written in a row, a note or a message is pasted from a command just run (**git rev-parse**), never typed or expanded from a short form. A queue that publishes (a public branch fed from the base) has the leader add a row for it on a schedule, gating what publishing needs, like any row.

**Restart onto a new bee.** After a landing that changes bee (**src/apps/bee.l** or **locks.l**), every live session restarts at its next convenient point: between tasks, never mid-gate, resuming in the same directory so **.mcp.json** loads the new bee. **queue_landed** ends the release note with this, and each session's own watch on its binary says it too.

## The tools

Every tool reads the queue fresh and writes it by compare-and-swap, reading again when someone wrote first. The queue must be named **refs/queue/***name*. No field may hold a control character, and only a text field (a note, a sync or pre line, a release note) may hold a space, so one field cannot write another row.

**queue_read** (*queue*)
:   The queue's text as it stands: header, rules, leader and rows. It writes nothing.

**queue_row** (*queue*, *state*, and any of *branch*, *gated_on*, *gated_head*, *note*, *row*, *keep*)
:   Sets exactly one of the caller's rows. A **waiting** join with a *gated_head* folds into the earliest waiting row ahead, as **Merge, not line up** says, and the answer says so. **keep 1** puts the row on the **keep** line: no join folds into it, and it folds into none. **keep 0** takes it off, and rows gone drop off the line. A session holds a row per branch: the write sets the row **row** names, else the row carrying **branch**, else the caller's only row, and a **branch** it holds no row for joins a new one. A new row joins at the bottom, at the **next** line's position, and moves that line past it; a queue without the line starts one past the highest position and writes it. **left** removes the row. Fields not given keep their values. It refuses:

    - a state outside the list above;
    - a write that cannot say which row, from a session holding more than one, naming neither *row* nor *branch*;
    - a new *branch* written onto a row that is folded or gating (pass the branch alone, to join a new row);
    - a fold by anyone but the leader (bee's own fold on a join aside);
    - a fold into a row that is missing, not waiting, or not ahead;
    - a fold of a row that others fold into;
    - a *gated_on* or *gated_head* that names no commit in the repository. The answer names it and says to paste it from **git rev-parse**.

    Only the leader may pass **session** to edit another's row, **base** to move the base line, or **position** to place a new row at a number no row holds. **leader** names the leader of a queue being made. When the queue is long, the answer says so and tells the model to fold, not line up.

**queue_gate** (*queue*, *dir*, *lanes*)
:   Gates the caller's row on a git queue: the head row, or the row behind a green one, its union merged and committed in *dir* (the working directory unless given), with its **out/** built. It refuses a row that is folded, a row behind one that is not green, and a *dir* with uncommitted changes or no **test/gate/lanes.sh**. It writes the row **gating** with *dir*'s HEAD and starts **love bee --gate** *queue* \[*lane* ...\] there, detached in its own group, as the caller. That runner refuses to start when it inherited any ignored signal, since every lane would inherit it too. It runs every lane the change owes from the row's gated-on (**love bee --lanes**, which for a union is the union of its branches' lanes), light and heavy, the slow lane last, through **test/gate/lanes.sh -d out/lanes-gate --slow** under the heavy lock (**love bee --lock --heavy**). Then it writes the row **green**, its note ending **| gate** *sha*: *lane***=***exit* for each lane, or **waiting** with the same note and **| red:** each red *lane* **owed by** the rows whose paths owe it. A member's paths are its own head's change from the row's gated-on, and a lane no member's paths owed is the row's own. Each owner is told, and the caller hears which rows to split out. After the split, *lanes* (the red ones, space-separated) runs only those again, with the slow lane: the lanes the last gate passed stand, the note says **| stood:** and names them, and the row is green when the rerun passes. The log is *dir***/out/gate.log**.

**queue_lead** (*queue*, and any of *leader*, *sync*, *pre_add*, *pre_drop*, *base*)
:   The leader's own lines, for the leader alone. **leader** hands the queue on. **base** moves the base line, touching no row. **sync** sets the sync line, and **-** removes it. **pre_add** adds a pre line, and **pre_drop** *n* drops the *n*th. The head row's session may pass itself as **leader** while the leader has no live session in the hive. That writes **leader** *itself* **acting**.

**queue_land** (*queue*)
:   Answers how to land the caller's row, and changes nothing. The row must be green and at the head. While the row ahead is merged onto the base but has not yet called **queue_landed**, it is still landing, its fast gate running in the base's checkout, and the answer says to wait for it. The row's gated-on and gated head must resolve here, as **queue_row** requires (and so must they for **queue_landed**). The base branch must be where the base line says, and **git merge-tree --write-tree** of the base and the gated head must give the gated tree. The answer is the checkout of the base, then **git rev-parse** of the base and the sha it must print, **git merge --no-ff** *sha*, **git rev-parse 'HEAD^{tree}'** with the tree it must print, and the fast gate under the checkout's out/ lock (**love bee --lock --out** *dir***/out -- make test**).

**queue_landed** (*queue*, optionally *release*)
:   After the landing, it walks the base's first-parent history since the base line (**git log --first-parent** *line*..*base*), oldest first, for a commit with the gated tree that merges the gated head: the head is one of its other parents, or an ancestor of one. Failing that, it takes the base's tip when the tip holds the gated head and has the gated tree. Only then does it drop the row and the rows folded into it and move the base line to that commit, keeping the line's note; when there is none, the row stays and the answer says what was checked. A *release* note goes to the sessions of the next row and the rows folded into it, and the answer names each session it reached and each it could not, for the caller to relay. Without one, the answer names those sessions. When the landed range, from the base line's old sha to the landing, touches bee's served code, the note ends with the restart line, and goes out even without a *release*.

## Watching

A session with rows watches the queues. It reads every queue again every **(queue-watch** *n***)** seconds (20 unless set, 0 for never), and a change that concerns its rows comes to it as a message from **queue-watch**:

- its own row leaving the queue;
- the row it stacks on (the nearest unfolded row above it) moving head or state, or leaving;
- a row folding into it, or a folded row moving;
- a new leader;
- the queue turning long.

The leader hears every row, with or without one of its own: each join, move and leaving. A session's own edits to its own rows say nothing.

Every watching session also watches for a stall at a queue's head: the head row's owner with no live session for **(gone-minutes** *n***)** (5); the head row green and not landed, or waiting with no row gating, for **(stall-minutes** *n***)** (30). A stall is known by its row, state and head, so a row that moves starts afresh. The first session to mark it in the hive (**.stall/**) rings: a message from **watchdog** to the leader, or, when the leader has no live session either, to every live session holding a row, who may take the lead (**queue_lead**, acting) and land or fold. It rings once per stall.

# EXAMPLES

Watch the queues and the locks, or print them once:

> ```
> love bee
> love bee --hud
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

**BEE_HOSTS**
:   The host registry, **~/.love/etc/bee/hosts** when unset.

# EXIT STATUS

**0** when the run ends normally. **--on** exits with its command's status, **75** when no host with the cap answers and **255** when ssh or the host fails. **--lock** exits with its command's status. **1** when a message cannot be delivered. **2** for a malformed **--send**, or an unknown option.

# SEE ALSO

**love**(1), **lush**(1), **cook**(1)
