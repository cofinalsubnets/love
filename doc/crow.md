---
title: CROW
section: 1
source: love @VERSION@
manual: love manual
---

# NAME

crow - a coding agent in the terminal, and the protocol its sessions talk by

# SYNOPSIS

**love crow** \[**-y**\] \[**--plain**\] \[*prompt* ...\]

**love crow --list**

**love crow --send** *name* *text* ...

# DESCRIPTION

**crow** puts a model to work in the current directory. The model has six tools: **read_file**, **write_file** and **edit_file**; **shell**, which runs a command line in **lush -a** (this binary's shell, with love's own verbs ahead of PATH); and **list_sessions** and **send_message**, described below. A write, an edit or a shell command asks y/n before it runs, unless **-y** is given. The others run without asking.

Given a *prompt*, crow runs one turn and exits, streaming the answer to standard output. With no prompt, it opens its full screen on a terminal and a **>** loop elsewhere, or on a terminal too with **--plain**.

The system prompt tells the model where it is:

- the date, the platform and, in a git repository, the branch, its status and recent commits;
- a briefing on love: the toolchain the binary carries, a primer on the language, and how to lay love's source and build it;
- its own session name, and how to reach other sessions;
- every merge queue under **refs/queue/**, as it stood at start (see THE MERGE QUEUE);
- the project's own instructions: from **/** down to the working directory, each directory's **AGENTS.md**, else its **CLAUDE.md**.

The settings are read from **~/.love/etc/crow.l** and then **./.crow.l**, one form per line: **(api anthropic)** or **(api openai)**, **(url** "...**)**, **(model** *name***)**, **(key-env** *var***)**, **(max-tokens** *n***)**, **(shell** *word* ...**)**, **(context** *n***)** and **(thinking off)**. A key goes out only over TLS, and only to a peer whose certificate this binary has verified. Plain HTTP reaches this machine alone.

# SESSIONS AND MESSAGES

Every running crow is a *session* with a name. It is **CROW_NAME** when that is set and free; otherwise it is the last part of the working directory followed by two hex digits. Sessions find each other, and write to each other, through plain files under the *roost*: **CROW_ROOST** when set, else **~/.love/run/crow**. Anything that can write a file can take part: a shell, a script, or another kind of agent.

A session keeps one directory, *roost***/***name***/**:

**card**
:   Who the session is, one *key value* pair a line: **pid**, **cwd**, **branch**, **model**, **state** (**idle**, **busy** or **asking**) and **since** (epoch seconds). It is rewritten whole, through a rename, on every change of state.

**inbox/**
:   The messages sent to the session, one file each.

**read/**
:   The messages the session has taken, moved there from **inbox/**.

A *message* file is a header and a body. The header is *key value* lines, **from** *name* and **sent** *seconds* among them; a blank line ends it, and everything after the blank line is the text. To send, write the file as **inbox/.***id* and then rename it to **inbox/***id*. A reader ignores dot files, so it never sees a message half written. Messages are taken in the order their ids sort, so an id should begin with the time in milliseconds; crow's own are *ms***-***sender***-***hex*.

A session is live while its card's **pid** is. Whoever lists the roost removes a perch whose card names a dead pid, along with its messages. A perch without a card is still being made, and is left alone. A session removes its own perch when it exits.

Messages are delivered at two points. While a turn runs, whatever has arrived joins the next request, beside that request's tool results. On the full screen, an idle session checks its inbox about once a second, and a message starts a turn of its own. The model reads each message as **\<message from="***name***"\>** ... **\</message\>** inside a user turn, and is told that it comes from another agent and not from the user.

The model's **list_sessions** tool reads the cards, and **send_message** writes a message as described above. From a shell, **love crow --list** prints the same list and **love crow --send** *name* *text* sends; the sender is **CROW_NAME**, else **cli-***user*.

# THE MERGE QUEUE

Sessions working in parallel often share one branch, and merge into it one at a time. crow does not impose a protocol for this: it reads one out of the repository. Every ref under **refs/queue/** is a queue, a blob whose header states its rules, names its leader, and holds a row per merge. crow quotes each queue in the system prompt as it stood at start, and tells the model to follow the rules, to read the queue fresh before acting on it, and to write only its own row. Writes are compare-and-swap: **git hash-object -w** *file*, then **git update-ref refs/queue/***name* *new* *old*. When that fails, someone wrote first: re-read and redo. A row names its session. The model reaches a crow session with **send_message**, and asks the user to relay to any other.

# EXAMPLES

Ask one thing, and let it act without asking:

> ```
> love crow -y 'make the tests pass'
> ```

See who is running, and send one of them a note:

> ```
> love crow --list
> love crow --send g-3f 'row 62 landed; rebase onto gwen'
> ```

Send the same note with nothing but a shell:

> ```
> d=~/.love/run/crow/g-3f/inbox; id=$(date +%s)000-me
> printf 'from me\n\nrow 62 landed\n' > "$d/.$id" && mv "$d/.$id" "$d/$id"
> ```

# ENVIRONMENT

**CROW_NAME**
:   This session's name, and the sender that **--send** signs with.

**CROW_ROOST**
:   The roost's directory, **~/.love/run/crow** when unset.

**ANTHROPIC_API_KEY**, **OPENAI_API_KEY**
:   The key, by default; **(key-env** *var***)** names another.

# EXIT STATUS

**0** when the run ends normally. **1** when the settings name no usable endpoint, model or key, or when a message cannot be delivered. **2** for a malformed **--send**.

# SEE ALSO

**love**(1), **lush**(1), **cook**(1)
