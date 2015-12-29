/*
 * Copyright (c) 2015 Thomas Daehling <doc@methedrine.org>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
module statsd;

import core.time;

import std.conv;
import std.random : uniform;
import std.socket : Address, getAddress, InternetAddress, SocketOption, SocketOptionLevel, UdpSocket;

class StatsClient
{
	/**
	* Create a StatsClient instance.
	* 
	* Params:
	*      host = the host on which the statsd server runs, defaults to "localhost".
	*      port = the port on which the statsd server runs, defaults to 8125.
	*      prefix = an optional prefix for stats recorded with this StatsClient instance.
	*      mtu = the maximum transmissions size, defaults to 0. Larger values automatically try to make use multimetric packages.
	*/
	this(string host="localhost", ushort port=8125, string prefix="", int mtu=0)
	{
		this(getAddress(host, port)[0], prefix, mtu);
	}

	/**
	* Create a StatsClient instance.
	*
	* Params:
	*      addr = the address at which the statsd server runs.
	*      prefix = an optional prefix for stats recorded with this StatsClient instance.
	*      mtu = the maximum transmissions size, defaults to 0. Larger values automatically try to make use multimetric packages.
	*/
	this(Address addr, string prefix="", int mtu=0)
	{
		socket = new UdpSocket;
		this.addr = addr;
		this.prefix = prefix;
		this.mtu = mtu;
	}

	~this()
	{
		if (this.payload.length > 0) {
			this.socket.sendTo(this.payload, addr);
		}
	}

	void inc(string stat, int count=1, float rate=1)
	{
		sendStat(stat, encodeValue(count, "c"), rate);
	}

	void dec(string stat, int count=1, float rate=1)
	{
		inc(stat, -count, rate);
	}

	void gauge(string stat, int value, float rate=1)
	{
		sendStat(stat, encodeValue(value, "g"), rate);
	}

	void set(string stat, int value, float rate=1)
	{
		sendStat(stat, encodeValue(value, "s"), rate);
	}

	void timing(string stat, int delta, float rate=1)
	{
		sendStat(stat, encodeValue(delta, "ms"), rate);
	}

	private string encodeValue(int value, string unit)
	{
		return to!string(value)~"|"~unit;
	}

	private string encodeStat(string stat, string value)
	{
		if ( this.prefix.length > 0 )
		{
			stat = prefix ~ "." ~ stat;
		}

		stat ~= ":"~value;

		return stat;
	}

	private void sendStat(string stat, string value, float rate)
	{
		if ( rate < 1.0 && uniform(0.0f, 1.0f) > rate)
		{
			return;
		}

		stat = encodeStat(stat, value);

		if (this.mtu > 0) {
			if ( ("\n".length + this.payload.length + stat.length) > this.mtu ) {
				this.socket.sendTo(this.payload, addr);
				this.payload = "";
			} 
			if ( this.payload.length > 0 ) {
				this.payload ~= "\n"~stat;
			} else {
				this.payload = stat;
			}
		} else {
			this.socket.sendTo(stat, addr);
		}
	}

	private string prefix = "";
	private string payload = "";
	private const int mtu = 0;
	private Address addr;
	private UdpSocket socket;

	private unittest
	{
		// 1. statsd client supports optional prefixes
		auto simpleTestClient = new StatsClient();
		assert(simpleTestClient.encodeStat("stat", "somevalue") == "stat:somevalue");

		auto prefixTestclient = new StatsClient("localhost", 8125, "test");
		assert(prefixTestclient.encodeStat("stat", "somevalue") == "test.stat:somevalue");

		// 2. encodes values according to specification (e.g. "value|unit")
		assert(simpleTestClient.encodeValue(42, "ms") == "42|ms");

		// 3. supports optional MTU declaration
		assert(simpleTestClient.mtu == 0);		

		auto mtuTestClient = new StatsClient("localhost", 8125, "", 32);
		assert(mtuTestClient.mtu == 32);

		// 4. multimetric package encoding
		mtuTestClient.timing("timer", 42);
		assert(mtuTestClient.payload.length < mtuTestClient.mtu);
		assert(mtuTestClient.payload == "timer:42|ms");
		mtuTestClient.timing("timer2", 4711);
		assert(mtuTestClient.payload.length < mtuTestClient.mtu);
		assert(mtuTestClient.payload == "timer:42|ms\ntimer2:4711|ms");

		// 5. multimetric package chopping
		mtuTestClient.timing("longTimerName", 42);
		assert(mtuTestClient.payload.length < mtuTestClient.mtu);
		assert(mtuTestClient.payload == "longTimerName:42|ms");
	}
}

class Timing
{
	this(StatsClient client, string name)
	{
		this.client = client;
		this.name = name;
		this.start = MonoTime.currTime;
	}

	~this()
	{
		this.client.timing(this.name, to!int((MonoTime.currTime - this.start).total!("msecs")));
	}

	private StatsClient client;
	private string name;
	private MonoTime start;
}
