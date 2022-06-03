
# ctx

This is a tool to rapidly tab-complete your way to a GKE context

## installation

Run `git clone git@github.com:ColinHeathman/ctx.git ~/.local/share/ctx`

Add this to `~/.bashrc` or `~/.bash_profile`:
```
alias ctx="source ${HOME}/.local/share/ctx/ctxrc"
source <(ctx completion)
```

eg.

```
cat >> ~/.bash_profile <<EOF

alias ctx="source \${HOME}/.local/share/ctx/ctxrc"
source <(ctx completion)

EOF
```
