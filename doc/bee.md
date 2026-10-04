---
title: BEE
section: 1
source: love @VERSION@
manual: love manual
---

# NAME

bee - a coding agent in the terminal, and the protocol its sessions talk by

# SYNOPSIS

**love bee**

**love bee --chat** \[**-y**\] \| **--hud**

**love bee** \[**-y**\] \[**--plain**\] \[*prompt* ...\]

**love bee --list**

**love bee --send** *name* *text* ...

**love bee --spawn** *name* *dir* \[**-y**\] *prompt* ...

**love bee --stop** *name*

**love bee --serve** \[**-y**\] \[*prompt* ...\]

**love bee --mcp**

**love bee --lock** \[**--heavy**\] \[**--out** *dir*\] **--** *command* ...

**love bee --avatar** \[*name*\]

**love bee --keygen root** \| **box** \[*name*\]

**love bee --ticket** \[*days*\] \| **--enrol** *token* \[*name*\] \| **--admit** \| **--enrolled**

**love bee --deliver** \| **--ledger**

**love bee --revoke** *pub* \| *name* \| **--revocations** \| **--revoked**

**love bee --state busy** \| **idle** \[**--pid** *pid*\]

**love bee --on** *cap* \[**--where** *key***=***value*\] \[**--ship** *dir*\] **--probe** \| **--ssh** \| **--** *command* ...

**love bee --hosts**

**love bee --nest** *dir*

**love bee --node**

**love bee --door** \[*key* ...\]

# DESCRIPTION

**bee** puts a model to work in the current directory. The model's tools:

- **read_file**, **write_file** and **edit_file**;
- **shell**, which runs a command line in **lush -a** (this binary's shell, with love's own verbs ahead of PATH);
- **list_sessions** and **send_message**, described under SESSIONS AND MESSAGES;
- **start_job**, **check_job** and **stop_job**, and **spawn_bee** and **stop_bee**, described under JOBS AND WORKERS;
- **lock_acquire**, **lock_release** and **lock_list**, described under LOCKS;
- **queue_read**, **queue_row**, **queue_lead**, **queue_land** and **queue_landed**, described under THE MERGE QUEUE.
- in a pane of **love mitty**, **pane_list**, **pane_read**, **pane_type**, **pane_open**, **pane_focus** and **pane_close**: the desktop's other panes by id, read as text, typed into as keys (a newline is Enter, and the answer is the pane once quiet), opened beside, given the keyboard, closed. The model's own pane is never typed into or closed.

A write, an edit, a shell command, a job's start, a message to another session, a queue write, a spawn and a stop of another bee, and typing into, opening, focusing or closing a pane ask y/n before they run, unless **-y** is given, and so does **read_file** of a path outside the working tree (a link out of it included). The rest run without asking. An ask shows the whole input, a control character as **^X**; on the full screen **y** runs it only once every row has been on the screen, and the arrows scroll it.

Given a *prompt*, bee runs one turn and exits, streaming the answer to standard output. With no prompt, on a terminal it shows the *hud*; elsewhere, or on a terminal with **--plain**, it runs a **>** loop. **--chat** opens the full screen, the chat with the model, directly.

The hud needs no model or key. It shows each merge queue: the base line and the leader, then every row (position, session, branch, gated-on, head and state), a folded row indented under the row it joins, the head row marked, and a note when the queue is long. Below the queues are the locks (the heavy tickets against **(heavy-max** *n***)**, the waiters, the **out/** locks and the hosts' **host-** slots, memory and load) and the sessions: each one's state and how long it has held it, and the time since its last bee tool call. It reads them all again every **(queue-watch** *n***)** seconds, 20 unless set, and on **r**. **q** quits; the arrows, **j** and **k** scroll. **--hud** prints it once, as text.

While it is open, the hud holds the *user's card*, at the login's name (**USER**), and the user talks to the hive through it. **c** or Enter opens a line to a session, the first queue's leader at first: Enter sends what is typed, Tab names the next session, and Esc goes back to looking. The talk shows under the queues, with whatever comes back to the user's name. A second hud for one login has no card, and only looks.

The full screen is also a pane: **(bee-main ["--stage"])**, called from love, settles a session and answers it as a stage for a **mitty**, so **love mitty** opens one beside its shells (**C-a b**). A stage that cannot start answers why as a string. Closing the pane ends the session's turn and leaves the hive.

The system prompt tells the model where it is:

- the date, the platform and, in a git repository, the branch, its status and recent commits;
- a briefing on love: the toolchain the binary carries, a primer on the language, and how to lay love's source and build it;
- its own session name, and how to reach other sessions;
- every merge queue under **refs/queue/**, as it stood at start (see THE MERGE QUEUE);
- the project's own instructions: from **/** down to the working directory, each directory's **AGENTS.md** and then its **CLAUDE.md**, both where both exist.

The settings are read from **~/.love/etc/bee.l**, one form per line: **(api anthropic)** or **(api openai)**, **(url** "...**)**, **(model** *name***)**, **(key-env** *var***)**, **(max-tokens** *n***)**, **(shell** *word* ...**)**, **(context** *n***)**, **(thinking off)**, **(avatar** *name***)**, **(relay** *word* ...**)** and **(ledger-dir** *path***)**. A key goes out only over TLS, and only to a peer whose certificate this binary has verified. Plain HTTP reaches this machine alone, and not a port another login (uid 1000 and up) listens on. A tree's own **./.bee.l** travels with a clone, so it may set only **model**, **max-tokens**, **thinking**, **context** and **queue-watch** over them.

# AVATARS

The hello box shows an avatar: eight by eight pixels drawn as four rows of half-blocks, in 24-bit colour when **COLORTERM** is **truecolor** or **24bit** and the nearest of 256 otherwise. They are **bunny** (the default), **bee**, **baby**, **hare**, **honeybee**, **beeface**, and **moon**, drawn by **love pom** at start as the moon stands then (UTC). The accent -- the box's border, the title, the spinner, the session's name and the mail marker -- follows it: the colour most of its vivid pixels share, or most of all its pixels when none is vivid.

**/avatar**, on the full screen or at the **>** prompt, draws them all with their names; **/avatar** *name* wears one at once, and **love bee --avatar** \[*name*\] does the same from a shell. The choice is kept as **(avatar** *name***)** in **~/.love/etc/bee.l**, replacing any before it; a tree's **./.bee.l** cannot set it. An unknown name is refused with the list of known ones.

# SESSIONS AND MESSAGES

Every running bee is a *session* with a name. It is **BEE_NAME** when that is set and free; otherwise it is the last part of the working directory followed by two hex digits. Sessions find each other, and write to each other, through plain files under the *hive*: **BEE_HIVE** when set, else **~/.love/run/hive**. Anything that can write a file can take part: a shell, a script, or another kind of agent.

A session keeps one directory in the hive, its *cell*, *hive***/***name***/**:

**card**
:   Who the session is, one *key value* pair a line: **pid**, **cwd**, **branch**, **model**, **state** (**idle**, **busy** or **asking**) and **since** (epoch seconds), and for a Claude Code session **turn**, when its state last moved, and **parent**, the pid of the Claude Code it serves. It is rewritten whole, through a rename, on every change of state.

**inbox/**
:   The messages sent to the session, one file each.

**read/**
:   The messages the session has taken, moved there from **inbox/**.

A *message* file is a header and a body. The header is *key value* lines, **from** *name* and **sent** *seconds* among them; a blank line ends it, and everything after the blank line is the text. To send, write the file as **inbox/.***id* and then rename it to **inbox/***id*. A reader ignores dot files, so it never sees a message half written. Messages are taken in the order their ids sort, so an id should begin with the time in milliseconds; bee's own are *ms***-***sender***-***hex*.

A session is live while its card's **pid** is. Whoever lists the hive removes a cell whose card names a dead pid, along with its messages. A cell without a card is still being made, and is left alone. A session removes its own cell when it exits.

A *user's card* is the person at a login, in the hive through the hud. It says **kind user** and **model user**, its name is the login's, and its **state** is **here** while a hud holds it (its pid the hud's) and **away** after. It is never removed, so mail to the user waits in its inbox until a hud opens. One login has one, no agent may settle or be named as it, and **love bee --list** shows it as **user**. A message the hud sends says **kind user** in its header.

Messages are delivered at two points. While a turn runs, whatever has arrived joins the next request, beside that request's tool results. On the full screen, an idle session checks its inbox about once a second, and a message starts a turn of its own. The model reads each message as **\<message from="***name***"\>** ... **\</message\>** inside a user turn, and is told that it comes from another agent and not from the user. A message that says **kind user** from a user's card reads as **\<message from="***name***" kind="user"\>**, and the model is told that it is the user, typing into the hud at this machine under the same login, to be taken as the user's own words and answered with **send_message** to that name. The login is the boundary of trust here: the hive is files any process of that uid can write, and the user's name is reserved against accidents, not against that uid.

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
- Its state is its Claude Code's turns, which the server cannot see. Love's tree carries **.claude/settings.json**, whose hooks run **love bee --state busy** when a prompt is submitted and **--state idle** when the turn stops, each with **--pid** of the Claude Code that ran it, in the background and quietly. They add **--hud**, which **--state** ignores, so a bee too old to know **--state** prints its hud and does nothing else. **--state** finds the session whose card's **parent** is that pid or one of its parents, else **BEE_NAME**'s, else the one Claude Code session in its directory, and moves the card's **state** and **turn**. Each tool call also touches *cell***/seen**, so the hud can say how long a session has been quiet even without the hooks.
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

# HOSTS

Work this box cannot do, or should not, runs on another: an a64 binary on an arm box, a kernel under kvm, a test on a BSD guest. The hosts a session may use are a registry, **~/.love/etc/bee/hosts** (**BEE_HOSTS** names another file), kept by **src/apps/hosts.l**. It holds a paragraph a host, each a run of *key value* lines like a card's, with a blank line between and **#** lines left out:

**name**
:   The host's name, which its locks carry.

**reach**
:   The words of the ssh that reaches it, **ssh** *name* unless given. bee adds batch mode and a short connect timeout just before the last word, so an option given here comes first and stands.

**slots**
:   How many pieces of work it takes at once, 1 unless given. Each slot is an exclusive lock, **host-***name***-***n*, so two lanes never crowd one box.

**caps**
:   What it can do, as words: **a64-exec** (runs linux/arm64 binaries), **kvm-a64** (boots an a64 guest under kvm), **vt-x** (boots an x64 guest that uses VT-x), **freebsd-x64**, **netbsd-x64**, **freebsd-a64**, **netbsd-a64** (that system, to test against).

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

The lanes ask for hosts this way: the a64 kernel lane boots on a **kvm-a64** host, the a64 lanes' binaries run on an **a64-exec** one, **test_kernel_vmx** boots on **vt-x**, and the BSD lanes find their boxes by their caps. A lane with a fallback takes 75 as its cue; one without skips loudly, which a strict box makes red. For one release the environment still names hosts, and a cap it names takes its hosts over the registry's: **KTEST_A64_HOSTS** (*host***:***slots* ...) for **a64-exec** and **kvm-a64**, **KTEST_VMX_HOSTS** for **vt-x**, and **FBSD_SSH**, **NBSD_SSH**, **FBSD_ARM64_SSH** and **NBSD_ARM64_SSH** (an ssh prefix each) for the four systems. A box joins the hive's lineage by enrolment (KEYS), and its registry entry says how its work reaches it.

# KEYS

Sessions on several boxes are to know each other by keys. A *lineage* is the boxes one root vouches for: the root is an ed25519 key, and its public half names the lineage. **src/apps/seals.l** makes the keys and *cards*. A card is *key value* lines, like a message's header: **lineage**, **name**, **kind** (**box** or **cell**), **pub**, **issued** and **expires** (epoch seconds), then **parent**, the signer's public key, and **sig**, the signer's signature over every line above it. Keys are lowercase hex. A *chain* is a card, then its signer's, each after a blank line, ending at a card the root signed. It holds when every card is in date, of the lineage, not revoked, and signed by the next card's key, and the next is a box. A cell's name is *name***@***box*, after the box that signed it.

The keys live in **~/.love/etc/bee/**. **love bee --keygen root** makes **root.key** and prints the lineage. **love bee --keygen box** \[*name*\] makes **box.key**, naming the box after the host unless a name is given. Where **root.key** is on the same box, it also signs **box.card** for a year and prints it; elsewhere it prints the box's public key, to be enrolled. A key file is created 0600 and never written over.

A box joins a lineage by enrolment, three steps that make one pipe:

> ```
> love bee --enrol TOKEN | ssh STEM love bee --admit | love bee --enrolled
> ```

On the box with **root.key**, **love bee --ticket** \[*days*\] mints a ticket, good once and for *days* (7). It prints a token, the lineage and the ticket, and keeps only the ticket's hash, in **tickets/**. On the new box, **--enrol** *token* \[*name*\] keeps the lineage in **lineage**, makes **box.key** if there is none, and prints a request: **name**, **pub** and **ticket**, signed by that key. A box is of one lineage, and a token of another is refused. **--admit** reads the request on its standard input, back on the root's box. It checks the signature, and that the ticket was minted there and is in date, then spends it, a file made once in **tickets/**, and prints the box's card for a year. **--enrolled** reads the card and keeps it as **box.card** when it checks against the lineage and names this box's key.

Where **box.key** and **box.card** are, a session seals what it sends. Its first message makes it a key, *cell***/key**, and **box.key** signs it a card named *name***@***box*, good for a day and signed again when it has less than an hour left; the chain, that card then **box.card**, is *cell***/cert**. A sealed message adds **to**, **id** (its file's name) and **cert** (the chain in base64) to its header, and ends the header with **sig**: the cell key's signature over every header line above it, the blank line and the text. A reader whose box has a card checks the chain against its lineage, then the signature, the **to**, the **id**, and that the card is named for the **from**. The model then reads the message as **\<message from="***name***" sealed="***name***@***box***"\>**. A message that fails is left in **read/** and shown only as a note from **bee**; so is one whose id was already taken. Plain mail, and any mail where the reader's box has no card, reads as before.

Mail goes to another box of the lineage when the name is *name***@***box* and *box* is not this one. It leaves only sealed. The sender runs **(relay** *word* ...**)** (**ssh -T** unless set) with the host and the remote **love**, then **bee --deliver**, and the message on its standard input. **~/.love/etc/bee/boxes** names the way to each box, a line each, *box* *host* \[*love*\]: the host is the box's name and the remote program **love** when there is no line. On the far box, **--deliver** keeps the message in the named session's inbox only when it is addressed to that box, the session is live, its id is not taken there, and its seal checks; it says why not otherwise and exits 1. A login meant only for mail can be held to it by the far box's sshd, with OpenSSH's **command="love bee --deliver",restrict** before the key in **authorized_keys**. The reply goes back the same way, to *name***@***box* as the **sealed** attribute gave it.

A queue lives in one box's hub, and the others reach it as **queue/***name***@***box* or **refs/queue/***name***@***box*. A call from another box goes there sealed, as a message to **ledger@***box* holding the tool and its input, by the same **(relay** ...**)**, to **bee --ledger**. That box checks the seal, takes the id once (**ledger-ids/**), and runs the tool in **(ledger-dir** *path***)**, else its HOME, as the session the seal names, *name***@***box*. So a row belongs to its sealed name, and the queue's rules hold across boxes as they do on one. Notices about a row on another box are not sent yet.

A key is revoked on the root's box: **love bee --revoke** *pub* or *name*, a name being a box admitted there. It writes **revoked** again, the lineage, a **serial** one higher and a **revoked** *pub* line for each key, signed by the root, and carries it by **(relay** ...**)** to **bee --revocations** on every box in **boxes**, saying which took it. A box keeps a list only when its root signed it and its serial is higher than the one it has; **--revocations** takes one on standard input, and **--revoked** prints this box's. Every check of a chain refuses a card whose key, or whose signer's key, is listed: mail is set aside, **--deliver** and **--ledger** refuse, **--admit** will not admit the key again, and a session's own card is not signed again. The root itself is not revoked; a lineage whose root is lost is made anew.

# NEW NODE

A *node* is a box that works on a queue whose hub another box keeps: it has a nest made from that hub, sends its patch sets there, and writes its rows there, all through the hub box's *door*. **love bee --node** checks a box in order and says the first step it lacks, with what to run; run it again after each step until it says the box is a node.

On the hub's box, **(hub** *path***)** in **~/.love/etc/bee.l** names the hub nest (**SB_HUB** still wins where it is set). The door is what another box's key may run there, held to it by sshd: **love bee --door** *key* prints the **authorized_keys** line for a public key, **command="env HOME=***home* *love* **bee --door",restrict** *key*, and its owner appends it. sshd then runs **--door** with the asked command in **SSH_ORIGINAL_COMMAND**, and the door runs only **bee --deliver**, **bee --ledger** and **bee --admit**, each of which checks its own seal or ticket, its own hello (**bee --door**: the box, the hub's psid and its queues), and **sb serve @hub**, the hub nest's side of an sb sync. Anything else is refused. Without a command, **love bee --door** prints the hello.

On the new box, in order:

1. **love, nested.** In a love tree, a seed or **love source** *dir*: **make**, then **./out/love nest -y**, which lays **~/.love/bin/love** and **lush**.
2. **the hub named.** **(hub** *name***@***box***)** in **~/.love/etc/bee.l**, where *box* keeps the hub; *name* is **hub**, the nest its door serves.
3. **the way to the box.** A line *box* *host* \[*love*\] in **~/.love/etc/bee/boxes**, as for mail (KEYS).
4. **the door.** The hub box's owner lays this box's ssh key behind the door. **--node** prints the line to give them.
5. **enrolment.** **love bee --ticket** on the hub's box, then here **love bee --enrol** *token* *name* **\| ssh** *host* **love bee --admit \| love bee --enrolled**, the admission going through the door (KEYS).
6. **a nest.** **love bee --nest** *dir* (**(nest** *path***)**, else **~/g**): **sb sync --take hub@***box* into a new directory, which pulls the hub's store and takes its head.
7. **love built in the nest.** **make** there; the cc on PATH builds the bootstrap, love builds the rest.
8. **Claude Code**, on PATH, and the tree's **.mcp.json** and **.claude/settings.json** in the nest, which come with the hub's head.

Once every step is done, **--node** lists the hub's queues, as the door's hello names them. Then start a session in the nest as above (THE MCP SERVER) and work as in a worker nest. The hub's queues are **queue/***name***@***box*: **queue_read** reads one, and a queue tool call goes there sealed and runs on the hub's box as *session***@***node* (KEYS). A row's head is the psid of the banked set that gated: **sb bank** *name*, then **sb sync --keep hub@***box* deposits it in the hub. **queue_land** called from another box does the hub's **take** itself, since only the hub's box can, and answers the head it reached; **queue_landed** follows as on one box. **sb sync --take hub@***box* brings the nest up to the hub's head after a landing.

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

**Land by sha.** The green head row lands its gated head with **git merge --no-ff** *sha*, and only when **git merge-tree --write-tree** of the base and *sha* gives *sha*'s own tree. After the landing, the base's first-parent line since the base line must hold a merge of *sha* with the gated tree. That merge, not the base's tip, is where the base line moves, so rows that land back to back are each recorded against their own merge. The lander then sends the next rows a *release note* naming what the merge removes, renames or moves. A session that cannot land (a sandbox that refuses the main checkout) hands the user the exact commands, with the shas and the tree each must print, so the landing can be checked without trusting it. It checks the checkout for someone's uncommitted edits first.

**Land by psid.** On an sb ledger a row's gated head is the *psid* of the patch set it gated: the worker banks that set (**sb bank** *name*) and deposits it in the hub (**sb sync --keep** *hub*), and the bank travels with it. The green head row lands it with **sb -C** *hub* **take** *psid*, and only when the hub's head is the base line and lies inside that set. The hub's tree is a pure function of the set it realizes, so the hub then realizes exactly the set that was gated, and there is no merge to check. After the landing the hub's head must be that psid, and the base line moves to it.

**The git mirror.** An sb queue whose header has a **mirror** *path* *branch* \[*keep* ...\] line (the leader's, set with **queue_lead**) writes each landing to git: **queue_landed** builds the hub's tree in a private index from the hub's blobs, keeps the parent's paths under each *keep* prefix (what the hub's store leaves out, such as generated artifacts), and commits it onto *branch* of the repository at *path*, the row's note its message, by compare-and-swap. A tip that already has that tree is left alone. It refuses a *branch* checked out anywhere but the hub, which would move under that checkout. When the mirror does not take the landing, the row stays.

A session works in a *worker nest*, as it would in a git worktree: **love bee --nest** *dir* makes *dir* from the hub (**SB_HUB**, else **(hub** ...**)**), pulling the hub's store and taking its head (**sb sync --take**), and seeding *dir*/**out/** from the hub's build when the hub is on this box. It refuses a *dir* that is already there. A hub on another box is *name***@***box* (NEW NODE).

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

**The owner lands.** The session whose row is green lands it, and then calls **queue_landed** with a release note; the leader lands only its own rows. Every sha or psid written in a row, a note or a message is pasted from a command just run (**git rev-parse**, **sb psid**), never typed or expanded from a short form. A queue that publishes (a public branch fed from the base) has the leader add a row for it on a schedule, gating what publishing needs, like any row.

**Restart onto a new bee.** After a landing that changes bee (**src/apps/bee.l**, **locks.l** or **seals.l**), every live session restarts at its next convenient point: between tasks, never mid-gate, resuming in the same directory so **.mcp.json** loads the new bee. **queue_landed** ends the release note with this, and each session's own watch on its binary says it too.

## The tools

Every tool reads the queue fresh and writes it by compare-and-swap, reading again when someone wrote first. The queue must be named **refs/queue/***name* or **queue/***name*. No field may hold a control character, and only a text field (a note, a sync or pre line, a release note) may hold a space, so one field cannot write another row. A tool that writes asks first, unless the session runs with **-y**.

**queue_read** (*queue*)
:   The queue's text as it stands: header, rules, leader and rows. It writes nothing and runs without asking. A queue on another box (**@***box*) is read there, like any queue call, so a node reads the hub's queues with it.

**queue_row** (*queue*, *state*, and any of *branch*, *gated_on*, *gated_head*, *note*, *row*)
:   Sets exactly one of the caller's rows. A session holds a row per branch: the write sets the row **row** names, else the row carrying **branch**, else the caller's only row, and a **branch** it holds no row for joins a new one. A new row joins at the bottom, at the **next** line's position, and moves that line past it; a queue without the line starts one past the highest position and writes it. **left** removes the row. Fields not given keep their values. It refuses:

    - a state outside the list above;
    - a write that cannot say which row, from a session holding more than one, naming neither *row* nor *branch*;
    - a new *branch* written onto a row that is folded or gating (pass the branch alone, to join a new row);
    - a fold by anyone but the leader;
    - a fold into a row that is missing, not waiting, or not ahead;
    - a fold of a row that others fold into.

    Only the leader may pass **session** to edit another's row, **base** to move the base line, or **position** to place a new row at a number no row holds. **leader** names the leader of a queue being made. When the queue is long, the answer says so and tells the model to fold, not line up.

**queue_lead** (*queue*, and any of *leader*, *sync*, *pre_add*, *pre_drop*, *base*, *mirror*)
:   The leader's own lines, for the leader alone. **leader** hands the queue on. **base** moves the base line, touching no row. **sync** sets the sync line, and **-** removes it. **pre_add** adds a pre line, and **pre_drop** *n* drops the *n*th. **mirror** sets an sb queue's mirror line, and **-** removes it. The head row's session may pass itself as **leader** while the leader has no live session in the hive. That writes **leader** *itself* **acting**.

**queue_land** (*queue*)
:   Answers how to land the caller's row, and changes nothing. The row must be green and at the head. On git, the base branch must be where the base line says, and **git merge-tree --write-tree** of the base and the gated head must give the gated tree. The answer is the checkout of the base, then **git rev-parse** of the base and the sha it must print, **git merge --no-ff** *sha*, and **git rev-parse 'HEAD^{tree}'** with the tree it must print. On sb, the hub's head must be the base line, the hub must hold the set the gated psid names, and the head must lie inside it (**sb within head** *psid*). The answer is **sb -C** *hub* **take** *psid*, then **sb -C** *hub* **psid** and the psid it must print.

**queue_landed** (*queue*, optionally *release*)
:   After the landing, it walks the base's first-parent history since the base line (**git log --first-parent** *line*..*base*), oldest first, for a commit with the gated tree that merges the gated head: the head is one of its other parents, or an ancestor of one. Failing that, it takes the base's tip when the tip holds the gated head and has the gated tree. Only then does it drop the row and the rows folded into it and move the base line to that commit, keeping the line's note; when there is none, the row stays and the answer says what was checked. On sb, the hub's head must be the gated psid, and the base line moves to it. A *release* note goes to the sessions of the next row and the rows folded into it, and the answer names each session it reached and each it could not, for the caller to relay. Without one, the answer names those sessions. When the landed range, from the base line's old sha or psid to the landing (on sb, **sb paths** of the two), touches bee's served code, the note ends with the restart line, and goes out even without a *release*.

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

**BEE_HOSTS**
:   The host registry, **~/.love/etc/bee/hosts** when unset.

**ANTHROPIC_API_KEY**, **OPENAI_API_KEY**
:   The key, by default; **(key-env** *var***)** names another.

# EXIT STATUS

**0** when the run ends normally. **--on** exits with its command's status, **75** when no host with the cap answers and **255** when ssh or the host fails. **1** when the settings name no usable endpoint, model or key, when a message cannot be delivered, or for an unknown **--avatar**, or when **--keygen** cannot make a key. **2** for a malformed **--send**.

# SEE ALSO

**love**(1), **lush**(1), **cook**(1)
