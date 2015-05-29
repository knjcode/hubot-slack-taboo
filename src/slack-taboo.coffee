# Description
#   A hubot script that does the things
#
# Configuration:
#   SLACK_API_TOKEN   - Slack API Token (default. undefined )
#   HUBOT_SLACK_TABOO_CHANNEL  - Target channel
#             (default. taboo_exp)
#   HUBOT_SLACK_TABOO_DURATION - Duration to reap in seconds (default. 5)
#   HUBOT_SLACK_TABOO_MECABDIC - Set dir as a system dicdir
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
Mecab = require 'mecab-async'
mecab = new Mecab()

apitoken = process.env.SLACK_API_TOKEN
targetroom = process.env.HUBOT_SLACK_TABOO_CHANNEL ? "taboo_exp"
duration = process.env.HUBOT_SLACK_TABOO_DURATION ? 3
mecabdic = process.env.HUBOT_SLACK_TABOO_MECABDIC

tabooChars = []

hiraganaChars = []
for i in [12353..12435]
  hiraganaChars.push String.fromCharCode(i)

commands = ['taboo', 'addtaboo', 'maddtaboo', 'reset']

module.exports = (robot) ->

  if mecabdic
    Mecab.command = "mecab -d " + mecabdic
    console.log "Mecab command: " + Mecab.command

  robot.brain.on "loaded", ->
    # "loaded" event is called every time robot.brain changed
    # data loading is needed only once after a reboot
    if !loaded
      try
        tabooChars = JSON.parse robot.brain.get "hubot-slack-taboo-tabooChars"
      catch error
        robot.logger.info("JSON parse error (reason: #{error})")
    loaded = true
    if !tabooChars
      tabooChars = []

  robot.hear /^taboo$/, (res) ->
    msgs = ["禁止文字数：" + tabooChars.length.toString()]
    diff = _.difference(hiraganaChars,tabooChars)
    if tabooChars.length < diff.length
      msgs.push "禁止文字：" + tabooChars
    else
      msgs.push  "使用可能文字：" + diff
    res.send msgs.join("\n")

  addTaboo = (tabooChar) ->
    tabooChars.push(tabooChar)
    robot.brain.set "hubot-slack-taboo-tabooChars", JSON.stringify tabooChars

  robot.hear /^addtaboo$/, (res) ->
    diff = _.difference(hiraganaChars,tabooChars)
    newtaboo = diff[Math.floor(Math.random() * diff.length)]
    addTaboo(newtaboo)
    res.send "禁止文字に「" + newtaboo + "」を追加しました"

  robot.hear /^maddtaboo (.)$/, (res) ->
    newtaboo = res.match[1]
    diff = _.difference(hiraganaChars,tabooChars)
    if ~diff.indexOf(newtaboo)
      addTaboo(newtaboo)
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
      isDelete = true
    else
      tokens = mecab.parseSync res.message.text
      console.log tokens
      #readings = (token[8] for token in tokens)
      readings = (token[1].split('\t')[0] for token in tokens)

      matches = []
      for token in tokens
        #if token[8]
        if t = token[1].split('\t')[0]
          #if tabooRegex.test jaco.katakanize token[8]
          if tabooRegex.test jaco.katakanize t
            matches.push token

      console.log "Reading: " + readings.join('')
      console.log 'matches num: ' + matches.length.toString()
      console.log 'matches: ' + JSON.stringify matches

      if matches.length > 0
        isDelete = true

    if isDelete
      if targetroom
        if res.message.room != targetroom
          return

      if matches
        msgs = []
        for match in matches
          #if match[8]
          if match[1].split('\t')[0]
            #msgs.push match[0] + "(" + match[8] + ")"
            msgs.push match[0] + "(" + match[1].split('\t')[0] + ")"
        res.send "Delete! " + msgs.join()
      else
        res.send "Delete!"

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
