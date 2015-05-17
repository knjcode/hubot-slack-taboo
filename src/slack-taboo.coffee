# Description
#   A hubot script that does the things
#
# Configuration:
#   SLACK_API_TOKEN   - Slack API Token (default. undefined )
#   HUBOT_SLACK_TABOO_CHANNEL  - Target channel
#             (default. taboo_exp)
#   HUBOT_SLACK_TABOO_DURATION - Duration to reap in seconds (default. 5)
#
# Commands:
#   N/A
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   knjcode <knjcode@gmail.com>

_ = require 'lodash'
jaco = require 'jaco'
kuromoji = require 'kuromoji'

apitoken = process.env.SLACK_API_TOKEN
targetroom = process.env.HUBOT_SLACK_TABOO_CHANNEL ? "taboo_exp"
duration = process.env.HUBOT_SLACK_TABOO_DURATION ? 5

tokenizer = null

tabooChars = []

hiraganaChars = []
for i in [12353..12435]
  hiraganaChars.push String.fromCharCode(i)

commands = ['taboo', 'addtaboo', 'reset']

module.exports = (robot) ->

  DIC_URL = __dirname + "/dict/"
  robot.logger.info "DIC_URL:" + DIC_URL

  kuromoji.builder({ dicPath: DIC_URL }).build (err, _tokenizer) ->
    tokenizer = _tokenizer
    console.log "tokenizer ready"
    console.log "tabooChars:" + tabooChars
    console.log "hiraganaChars:" + hiraganaChars

    # hoges = tokenizer.tokenize("残像に口紅を")

    # hoges_pron_join = (hoge['pronunciation'] for hoge in hoges)
    # console.log hoges_pron_join.join('')

    # hoges_reading_join = (hoge['reading'] for hoge in hoges)
    # console.log hoges_reading_join.join('')
  addTabooChars = (chars) ->
    console.log 'addtabooChars'

#HIRAGANA_CHARS: '\\u3041-\\u3096\\u309D-\\u309F'

  robot.hear /^taboo$/, (res) ->
    msgs = [
      "禁止文字数：" + tabooChars.length.toString(),
      "禁止文字：" + tabooChars,
      "使用可能文字：" + _.difference(hiraganaChars,tabooChars)
    ]
    res.send msgs.join("\n")

  robot.hear /^addtaboo$/, (res) ->
    diff = _.difference(hiraganaChars,tabooChars)
    newtaboo = diff[Math.floor(Math.random() * diff.length)]
    tabooChars.push(newtaboo)
    res.send "禁止文字に「" + newtaboo + "」を追加しました"

  robot.hear /^maddtaboo (.)$/, (res) ->
    newtaboo = res.match[1]
    diff = _.difference(hiraganaChars,tabooChars)
    if ~diff.indexOf(newtaboo)
      tabooChars.push(newtaboo)
      res.send "禁止文字に「" + newtaboo + "」を追加しました"

  robot.hear /^reset$/, (res) ->
    tabooChars = []
    res.send "禁止文字をリセットしました"

  robot.hear /.*/, (res) ->
    for command in commands
      if res.message.text is command
        return

    isDelete = false
    tabooRegex = RegExp("[#{jaco.katakanize(tabooChars)}]")

    if tabooRegex.test jaco.katakanize res.message.text
      #res.send "HIT!!!"
      isDelete = true
    else
      tokens = tokenizer.tokenize res.message.text
      console.log "tokens:" + JSON.stringify tokens

      pronun = (token['pronunciation'] for token in tokens)
      reading = (token['reading'] for token in tokens)

      matches = []
      for token in tokens
        if token['reading']
          if tabooRegex.test jaco.katakanize token['reading']
            matches.push token
        # if token['pronunciation']
        #   if tabooRegex.test jaco.katakanize token['reading']
        #     matches.push token

      console.log "Pronunciation: " + pronun.join('')
      console.log "Reading: " + reading.join('')
      console.log 'matches num: ' + matches.length.toString()
      console.log 'matches: ' + JSON.stringify matches
      if matches.length > 0
        #res.send "HIT!!!"
        isDelete = true

    if isDelete
      if targetroom
        if res.message.room != targetroom
          return

      res.send "Delete!"
      if matches
        for match in matches
          if match['surface_form']
            res.send match['surface_form'] + "(" + match['reading'] + ")"

      msgid = res.message.id
      channel = res.message.rawMessage.channel
      rmjob = ->
        echannel = escape(channel)
        emsgid = escape(msgid)
        eapitoken = escape(apitoken)
        robot.http("https://slack.com/api/chat.delete?token=#{eapitoken}&ts=#{emsgid}&channel=#{echannel}")
          .get() (err, resp, body) ->
            try
              json = JSON.parse(body)
              if json.ok
                robot.logger.info("Removed #{res.message.user.name}'s message \"#{res.message.text}\" in #{res.message.room}")
              else
                robot.logger.error("Failed to remove message")
            catch error
              robot.logger.error("Failed to request removing message #{msgid} in #{channel} (reason: #{error})")
      setTimeout(rmjob, duration * 1000)
