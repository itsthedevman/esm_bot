# frozen_string_literal: true

describe ESM::Bot::ReplyOverseer do
  before :each do
    ESM.bot.reply_overseer.instance_variable_set("@entries", {})
  end

  it "is valid" do
    expect(ESM.bot.reply_overseer).not_to be(nil)
  end

  it "watches over the event" do
    expect(ESM.bot.watch(user_id: "hello", channel_id: "world")).to be(true)
    expect(ESM.bot.reply_overseer.watching?(user_id: "hello", channel_id: "world")).to be(true)
  end

  it "calls the callback (message received)" do
    event = nil

    ESM.bot.watch(user_id: "hello", channel_id: "world") do |incoming_event|
      event = incoming_event
    end

    ESM.bot.reply_overseer.on_message({ user: { id: "hello" }, channel: { id: "world" } }.to_ostruct)

    expect(event).not_to be(nil)
    expect(event.user.id).to eq("hello")
    expect(event.channel.id).to eq("world")
  end

  # Because why not
  it "calls the callback (threaded)" do
    event = nil

    ESM.bot.watch(user_id: "hello", channel_id: "world") do |incoming_event|
      event = incoming_event
    end

    thread_one = Thread.new do
      event = nil

      ESM.bot.watch(user_id: "foo", channel_id: "bar") do |incoming_event|
        event = incoming_event
      end

      ESM.bot.reply_overseer.on_message({ user: { id: "foo" }, channel: { id: "bar" } }.to_ostruct)

      expect(event).not_to be(nil)
      expect(event.user.id).to eq("foo")
      expect(event.channel.id).to eq("bar")
    end

    thread_two = Thread.new do
      event = nil

      ESM.bot.watch(user_id: "bin", channel_id: "baz") do |incoming_event|
        event = incoming_event
      end

      ESM.bot.reply_overseer.on_message({ user: { id: "bin" }, channel: { id: "baz" } }.to_ostruct)

      expect(event).not_to be(nil)
      expect(event.user.id).to eq("bin")
      expect(event.channel.id).to eq("baz")
    end

    ESM.bot.reply_overseer.on_message({ user: { id: "hello" }, channel: { id: "world" } }.to_ostruct)

    expect(event).not_to be(nil)
    expect(event.user.id).to eq("hello")
    expect(event.channel.id).to eq("world")

    thread_two.join
    thread_one.join
  end

  it "calls the callback (no reply)" do
    triggered = false
    ESM.bot.watch(user_id: "hello", channel_id: "world", expires_at: 1.second.from_now) do |event|
      expect(event).to be(nil)
      triggered = true
    end

    wait_for { triggered }.to be(true)
  end
end
