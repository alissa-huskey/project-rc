This is to help me keep track of which function does what. Obviously better
names are needed.

```

cd -> p:env:cd -> \cd && p:env:init
                      -> p:env:load envfile=$(p:_find_up) -> p:env:exit -> on_exit
                                                                        -> unset -f on_exit
                                                                        -> unset -f on_enter
                                                                        -> unset PROJECT_ROOT PROJECT_ENVFILE
                                                          -> p:env:source -> p:_is_authed || p:_auth
                                                                                         && source $envfile
                                                                          && p:env:enter -> p:is_authed
                                                                                         -> on_enter
```
