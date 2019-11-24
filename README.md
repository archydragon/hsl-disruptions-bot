# HSL disruption bot

Small Slack bot to post about disruptions and route cancellations in HSL transport network.


## Configuration

All configuration is being done by setting environment variables.

**Variable**         | **Description**                                                         | **Default value**
---------------------|-------------------------------------------------------------------------|-------------------
 `SLACK_BOT_TOKEN`   | Slack bot token (starts from `xoxb-*`).                                 | Required.
 `SLACK_CHANNEL_ID`  | Slack channel ID to post updates to.                                    | Required.
 `MESSAGES_LANGUAGE` | Preferred language for disruptions messages. Can be `en`, `fi` or `sv`. | `en`


## Running locally

Requires Elixir 1.9 or higher installed.

```bash
mix deps.get
mix run --no-halt
```


## Running with Docker Compose

Set environment variables in host machine shell or in `.env` file.

```bash
docker-compose up --build
```


## License

MIT (see LICENSE file for the details).
