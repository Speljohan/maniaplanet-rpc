maniaplanet-rpc
======

Maniaplanet RPC is a Ruby implementation of the XML-RPC variant used by Maniaplanet games (Trackmania, Shootmania).
The intended usage is creating custom controllers using the Ruby programming language, rather PHP, which is the default.

Installation
------------

To install the gem, run the following command:
```
gem install maniaplanet-rpc
```
Or if you are using a Gemfile:
```
gem 'maniaplanet-rpc'
```
Usage
-----

First, ensure that you have XML-RPC activated in your maniaplanet server. Assuming it listens on port 5000 on your local pc:
```ruby
require 'maniaplanet_rpc'

client = ManiaplanetClient.new "127.0.0.1", 5000
client.call "EnableCallbacks", true # Anonymous call (no response)
client.call "GetStatus" do |response| # Handle the response
  puts response
end
```

Issues
------

The gem currently does not handle callbacks.

Credits
-------

Johan Ljungberg - Initial implementation
Nadeo - Providing the awesome platform and games