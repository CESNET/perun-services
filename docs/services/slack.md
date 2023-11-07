# slack

### [GEN](../concepts/gen.md)

Gen script prepares users data and memberships in channels (Perun resources). Channels can be public or private.
There is a general channel in every Slack workspace, which contains all regular members.
Perun manages the general channel either by including all members of propagated resources, or by including members
of only specified resource(s). That is marked by _isSlackPrivateChannel_ and _isSlackGeneralChannel_ attributes in Perun.

### [SEND](../concepts/send.md)
Send script connects to Slack APIs using SlackSDK library - SCIM for managing users and Web API for channels management.
Different token types are used for communication with each of them (in SCIM the operations are handled on behalf
of the user, in Web API on behalf of the bot).
Slack regular users are fully managed by Perun. When user is no longer propagated from Perun,
it is disabled in Slack and notification is sent to configured channel. It can be then
turned to multichannel or singlechannel guest manually. Such guest can be turned to regular
user again by Perun. Membership is managed by Perun only in channels where configured bot account is integrated.
Channels where bot is integrated which are no longer propagated from Perun are archived.
Dearchivation can only be done manually.
If channel was created by Perun as public, it cannot be changed to private and vice versa.

### Dependencies
SlackSDK needs to be installed (https://pypi.org/project/slack-sdk/).