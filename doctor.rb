require 'rubygems'
require 'yaml'
require 'xmpp4r-simple'
require 'rbosa'

class Doctor

  def initialize(jid, password, logger=nil)
    @jid = jid
    @password = password
    @logger = logger
    log("starting up")
  end

  def run
    jabber.received_messages.each do |message|
      response = process(message) rescue "Exception..."
      jabber.deliver(message.from, response)
    end
  end
  
  def process(message)
    cmd = message.body.strip.downcase.split(' ').first
    case cmd
    when 'help'
      'current commands: play pause stop'
    when 'accept'
      jabber.accept_subscriptions = true
      'accepting new users'
    when 'unaccept'
      jabber.accept_subscriptions = false
      'not accepting new users'
    when 'play'
      itunes = OSA.app('iTunes')
      itunes.play
      "playing: #{itunes.current_track.artist}, #{itunes.current_track.name}"
    when 'pause'
      itunes = OSA.app('iTunes')
      itunes.pause
      "paused: #{itunes.current_track.artist}, #{itunes.current_track.name}"
    when 'stop'
      itunes = OSA.app('iTunes')
      itunes.stop
      'stopped'
    else
      "unknown command: #{message.body}, try: help"
    end
  end

  private

  def jabber
    begin
      unless @jabber
        log("connecting....")
        @jabber = Jabber::Simple.new(@jid, @password, :chat, "I'm the Doctor") 
      end  
    rescue => e
      log("[#{Time.now}] Couldn't connect to Jabber (#{@jid}, #{@password}): #{e}.")
      sleep 60
      retry
    end
    @jabber
  end

  def log(msg)
    msg = "#{@screen_name}: #{msg}"
    
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
