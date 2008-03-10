require 'rubygems'
require 'yaml'
require 'xmpp4r-simple'
require 'rbosa'
require 'chronic'

module Jabber
  class Simple
    def contact_list
      roster.items.values.collect { |item| item.jid.to_s if item.subscription != :none or item.ask == :subscribe }.compact.join(' ')
    end
  end
end

class Doctor

  def initialize(jid, password, logger=nil)
    @jid = jid
    @password = password
    @logger = logger
    @queued = {}
    log("starting up")
  end

  def run
    @queued.each do |key, cmds|
      next if key > Time.now
      log "event schedule for #{key.to_s}"
      cmds.each do |cmd|
        itunes.send cmd
      end
      @queued.delete(key)
    end
    jabber.received_messages.each do |message|
      response = process(message) rescue "Exception..."
      jabber.deliver(message.from, response)
    end
  end
  
  def process(message)
    cmd = message.body.strip.downcase.split(' ').first
    options = message.body.strip.split(' ')[1..-1].join(' ')
    case cmd
    when 'help'
      'current commands: play pause stop'
    when 'accept'
      jabber.accept_subscriptions = true
      'accepting new users'
    when 'unaccept'
      jabber.accept_subscriptions = false
      'not accepting new users'
    when 'add'
      jabber.add(*options.split(' '))
      'roster: ' + jabber.contact_list
    when 'remove'
      jabber.remove(*options.split(' '))
      'roster: ' + jabber.contact_list
    when 'roster'
      'roster: ' + jabber.contact_list
    when 'play'
      itunes.play
      "playing"
    when 'pause'
      itunes.pause
      "paused"
    when 'stop'
      itunes.stop
      'stopped'
    when 'sleep'
      whenz = Chronic.parse(options)
      @queued[whenz] ||= [] << :pause
      "pausing at #{whenz}"
    when 'clear'
      @queued.clear
      'all events removed'
    else
      "unknown command: #{message.body}, try: help"
    end
  end

  private

  def jabber
    begin
      unless @jabber
        log("connecting....")
        @jabber = Jabber::Simple.new(@jid, @password, :chat, "I'm the Doctor, ask for help...") 
      end  
    rescue => e
      log("Couldn't connect to Jabber (#{@jid}, #{@password}): #{e}.")
      sleep 60
      retry
    end
    @jabber
  end
  
  def itunes
    @itunes ||= OSA.app('iTunes')
  end

  def log(msg)
    msg = "[#{Time.now}]: #{msg}"
    
    if @logger
      @logger.info(msg)
    else
      STDERR.puts(msg)
    end
  end
end

auth = YAML.load(File.read("auth.yml"))
bot = Doctor.new(*auth)
loop do
  bot.run
  sleep 0.5
end
