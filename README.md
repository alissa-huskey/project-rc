Project-RC
===========
> per-project shell env files [alissa-huskey/project-rc](https://github.com/alissa-huskey/project-rc)

Usage
-----

In the project root directory, add a `.env` file. In it, define a `on_enter` to
be run when you CD into the project or one of its subdirectories, and `on_exit`
function to be run on the reverse.

```sh
# $PROJECT_ROOT/.env

on_enter() {
  project:export PATH "$PATH:$PROJECT_ROOT/src/bin"
}

on_exit() {
  project:revert PATH
}
```

Behavior
--------

* Works by aliasing `cd`
* Walks up the tree from the current directory to find a .env file
* Prompt on first sourcing of envfile then saves `gpg` list of authorized paths to `~/.projectrc-auth`

Features
--------

* `$PROJECT_ROOT` environment variable
* `project:export <varname> <value>` - exports `<varname>` to `<value>` and saves previous value.
* `project:revert <varname>` - set `<varname>` to previously set value.

Requirements
------------

* gpg, pinentry
* bash 3+ or zsh 5+

Install
-------

At the command line:

```
git clone https://github.com/alissa-huskey/project-rc ~/.project-rc
```

Setup
-----

### Create GPG key

At the command line:

```bash
brew install pinentry
mkdir -p ~/.gnupg && touch ~/.gnupg/gpg-agent.conf
cp ~/.gnupg/gpg-agent.conf  ~/.gnupg/gpg-agent.conf
sed -i'' -e "/^pinentry-program/ { s_^pinentry-program .*\$_pinentry-program $(command -v pinentry)_ }" ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
gpg --quick-gen-key "NAME <EMAIL>" rsa4096 encr,sign,auth,cert -
```

### Add to profile

#### BASH:

In your `~/.bashrc` or `~/.bash_profile`:

```bash
alias cd='project:env:cd'
```

#### ZSH:
In your `~/.zshrc`:

```
autoload -U add-zsh-hook
add-zsh-hook chpwd project:env:init
```

#### ALL shells

In your `~/.zshrc` or `~/.bashrc`:

```
source ~/.project-rc/project-rc.sh

# uncomment the following line to enable debug mode
# DEBUG=true

# after starting a new terminal, load any project .env file
# in the startup directory

if command -v project:env:init > /dev/null; then
  project:env:init
fi
```

Alternatives
------------

You should probably use one of these other projects instead.

- [direnv](https://github.com/direnv/direnv)
- [smartcd](https://github.com/cxreg/smartcd)
- [ondir](https://swapoff.org/ondir.html)
- [autoenv](https://github.com/inishchith/autoenv)
- [Environment Modules](http://modules.sourceforge.net/)
- [zsh-autoenv](https://github.com/Tarrasch/zsh-autoenv)
