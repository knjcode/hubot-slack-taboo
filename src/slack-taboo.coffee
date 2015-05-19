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
kuromoji = require 'kuromoji'
Mecab = require 'mecab-async'
mecab = new Mecab()

apitoken = process.env.SLACK_API_TOKEN
targetroom = process.env.HUBOT_SLACK_TABOO_CHANNEL ? "taboo_exp"
duration = process.env.HUBOT_SLACK_TABOO_DURATION ? 5
mecabdic = process.env.HUBOT_SLACK_TABOO_MECABDIC ? ""

tokenizer = null

tabooChars = []

hiraganaChars = []
for i in [12353..12435]
  hiraganaChars.push String.fromCharCode(i)

commands = ['taboo', 'addtaboo', 'maddtaboo', 'reset']

module.exports = (robot) ->

  # DIC_URL = __dirname + "/dict/"
  # robot.logger.info "DIC_URL:" + DIC_URL

  # kuromoji.builder({ dicPath: DIC_URL }).build (err, _tokenizer) ->
  #   tokenizer = _tokenizer
  #   console.log "tokenizer ready"
  #   console.log "tabooChars:" + tabooChars
  #   console.log "hiraganaChars:" + hiraganaChars

  if mecabdic
    Mecab.command = "mecab -d " + mecabdic
    console.log "Mecab command: " + Mecab.command

  # tokens = mecab.parseSync "中居正広の金曜日のスマたちへ"
  # for token in tokens
  #   console.log token[7]


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
      isDelete = true
    else
      # tokens = tokenizer.tokenize res.message.text
      # console.log "tokens:" + JSON.stringify tokens

      # pronun = (token['pronunciation'] for token in tokens)
      # reading = (token['reading'] for token in tokens)
      tokens = mecab.parseSync res.message.text
      # console.log tokens
      reading = (token[8] for token in tokens)

      matches = []
      for token in tokens
        if token[8]
          if tabooRegex.test jaco.katakanize token[8]
            matches.push token
        # if token['pronunciation']
        #   if tabooRegex.test jaco.katakanize token['reading']
        #     matches.push token

      # console.log "Pronunciation: " + pronun.join('')
      console.log "Reading: " + reading.join('')
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
          if match[8]
            msgs.push match[0] + "(" + match[8] + ")"
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
