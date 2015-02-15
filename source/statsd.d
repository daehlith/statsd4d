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

import std.random : uniform;
import std.socket : Address, getAddress, InternetAddress, SocketOption, SocketOptionLevel, UdpSocket;

class StatsClient
{
	/**
	* Create a StatsClient instance.
	* 
	* Params:
	*      host = the host on which the statsd server runs.
	*      port = the port on which the statsd server runs.
	*      prefix = an optional prefix for stats recorded with this StatsClient instance.
	*      mtu = the maximum transmissions size, defaults to 512 which is reasonable for UDP packets on commodity internet.
	*/
	this(string host, ushort port, string prefix="")
	{
		this(getAddress(host, port)[0], prefix);
	}

	/**
	* Create a StatsClient instance.
	*
	* Params:
	*      addr = the address at which the statsd server runs.
	*      prefix = an optional prefix for stats recorded with this StatsClient instance.
	*/
	this(Address addr, string prefix="")
	{
		socket = new UdpSocket;
		this.addr = addr;
		this.prefix = prefix;
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

	private string encodeTiming(int value, string unit)
	{
		return delta.stringof~"|"~unit;
	}

	private string encodeStat(string stat, string value)
	{
		if ( this.prefix.length > 0 )
		{
			stat = prefix ~ "." ~ stat;
		}

		stat ~= ":"~value.stringof;

		return stat;
	}

	private void sendStat(string stat, string value, float rate)
	{
		if ( rate < 1.0 && uniform(0.0f, 1.0f) > rate)
		{
			return;
		}

		stat = encodeStat(stat, value);

		this.socket.sendTo(stat, addr);
	}

	private string prefix = "";
	private Address addr;
	private UdpSocket socket;

	private unittest
	{
		// 1. statsd client supports optional prefixes
		auto simpleTestClient = new StatsClient("localhost", 8125);
		assert(simpleTestClient.encodeStat("stat", "value") == "stat:value");

		auto prefixTestclient = new StatsClient("localhost", 8125, "test");
		assert(prefixTestclient.encodeStat("stat", "value") == "test.stat:value");

		// 2. encodes values according to specification (e.g. "value|unit")
		assert(simpleTestClient.encodeValue(42, "ms") == "42|ms");
	}
}