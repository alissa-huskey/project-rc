Project-Env
===
> per-project shell env files

Setup
---

In the appropriate shellrc file, source `project-rc.sh` and then call `project:env:load`.

```sh
# $HOME/.profile

source "project-rc.sh"
project:env:load
```

Usage
---

In the project root directory, add a `.env` file. In it, define a `on_enter` to be run when you CD into the project or one of its subdirectories, and `on_exit` function to be run on the reverse.

```sh
# $PROJECT_ROOT/.env

on_enter() {
  project:export PATH "$PROJECT_ROOT/src/bin"
}

on_exit() {
  project:revert PATH
}
```
Behavior
---

* Works by aliasing `cd`
* Walks up the tree from the current directory to find a .env file
* Prompt on first sourcing of envfile then saves `gpg` list of authorized paths to `~/.projectrc-auth`

Features
---

* `$PROJECT_ROOT` environment variable
* `$PROJECT_ENVFILE` environment variable
* `project:export <varname> <value>` - exports `<varname>` to `<value>` and saves previous value.
* `project:revert <varname>` - set `<varname>` to previously set value.

Requirements
---

- gpg with a default key created
- bash 3+ or zsh 5+


Alternatives
---

You should probably use one of these other projects instead.

- [direnv](https://github.com/direnv/direnv)
- [smartcd](https://github.com/cxreg/smartcd)
- [ondir](https://swapoff.org/ondir.html)
- [autoenv](https://github.com/inishchith/autoenv)
- [Environment Modules](http://modules.sourceforge.net/)
- [zsh-autoenv](https://github.com/Tarrasch/zsh-autoenv)
