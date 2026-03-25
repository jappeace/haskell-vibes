# Haskell vibes
I do not actually trust these llm's,
but I"m not going to babysit their every
action, so I run them in a container.

This allows you to run multiple instances at the same time as well.
Allowing you to bypass the need to make it smart or lazy.

Claude doesn't get to see how we start the container.
It could (probably unintentionally) use the knowledge of the runtime setup to escape.
Having to find this public repo is just one more step.

https://jappie.me/haskell-vibes.html

## Usage
You need a `~/.gh_token`, create a seperate git bot account to give your llm git access.
I recommend against giving it access to your main account for two reason:
1. Visibility: show everyone this is a bot. 
2. Security: you don't want this thing to do destructive actions by accident.

To create the token:
1. click on your user profile.
2. go to settings
3. at the menu on the left all the way down click to developer settings
4. Personal access tokens
5. Tokens classic with these permissions at least: `admin:org_hook, admin:public_key, admin:repo_hook, codespace, gist, notifications, project, repo, workflow, write:discussion, write:packages`.
   a. I set them to never expire to avoid busy work, it'll bitch and moan about it, but entropy will taken the token eventually.

You also need to create a seperate ssh key for your new github account. 
```
ssh-keygen -t ed25519 -C "sloth" -f /home/YOUR-USER/.ssh/sloth
```
This allows it to clone and push via normal git commands on it's own account.

spin up stan:
```
./stan.sh 
```

open another terminal to spin up kyle.sh
```
./kyle.sh
```

you can see instances for more examples


### WARNING
I've seen it attempt to write into /etc/shadow 
to solve the home folder not being writable.

That's an attempt at privilege escalation!
