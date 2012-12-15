Juno: A unified interface for key/value stores
================================================

[![Build Status](https://secure.travis-ci.org/minad/juno.png?branch=master)](http://travis-ci.org/minad/juno) [![Dependency Status](https://gemnasium.com/minad/juno.png?travis)](https://gemnasium.com/minad/juno) [![Code Climate](https://codeclimate.com/badge.png)](https://codeclimate.com/github/minad/juno)

Juno provides a standard interface for interacting with various kinds of key/value stores. Juno
is based on Moneta and replaces it with a mostly compatible interface. The reason for the
fork was that Moneta was unmaintained for a long time.

Juno is very feature rich:

* Supports a lot of backends (See below)
* Supports proxies (Similar to [Rack middlewares](http://rack.github.com/))
* Custom serialization via `Juno::Transformer` proxy (Marshal/JSON/YAML and many more)
* Custom key transformation via `Juno::Transformer` proxy
* Value compression via `Juno::Transformer` proxy (Zlib, Snappy, QuickLZ, LZO)
* Expiration for all stores (Added via proxy if not supported natively)
* Integration with Rack as session store and Rack-Cache

Supported backends
------------------

Out of the box, it supports the following backends:

* Memory:
    * In-memory store (:Memory)
    * LRU hash (:LRUHash)
    * LocalMemCache (:LocalMemCache)
    * Memcached store (:Memcached, :MemcachedNative and :MemcachedDalli)
* Relational Databases:
    * DataMapper (:DataMapper)
    * ActiveRecord (:ActiveRecord)
    * Sequel (:Sequel)
    * Sqlite3 (:Sqlite)
* Filesystem:
    * PStore (:PStore)
    * YAML store (:YAML)
    * Filesystem directory store (:File)
    * Filesystem directory store which spreads files in subdirectories using md5 hash (:HashFile)
* Key/value databases:
    * Berkeley DB (:DBM)
    * GDBM (:GDBM)
    * SDBM (:SDBM)
    * Redis (:Redis)
    * Riak (:Riak)
    * TokyoCabinet (:TokyoCabinet)
    * Cassandra (:Cassandra)
* Document databases:
    * CouchDB (:Couch)
    * MongoDB (:Mongo)
* Other
    * Fog cloud storage which supports Amazon S3, Rackspace, etc. (:Fog)
    * Storage which doesn't store anything (:Null)

Supported serializers:

* Marshal
* YAML
* JSON (via multi_json)
* MessagePack
* BSON
* Ox
* BERT

Proxies
-------

In addition it supports proxies (Similar to [Rack middlewares](http://rack.github.com/)) which
add additional features to storage backends:

* `Juno::Proxy` proxy base class
* `Juno::Expires` to add expiration support to stores which don't support it natively
* `Juno::Stack` to stack multiple stores (Read returns result from first where the key is found, writes go to all stores)
* `Juno::Transformer` transforms keys and values (Marshal, YAML, JSON, Base64, MD5, ...)
* `Juno::Cache` combine two stores, one as backend and one as cache (e.g. Juno::Adapters::File + Juno::Adapters::Memory)
* `Juno::Lock` to make store thread safe
* `Juno::Logger` to log database accesses

The Juno API is purposely extremely similar to the Hash API. In order so support an
identical API across stores, it does not support iteration or partial matches.

Links
-----

* Source: <http://github.com/minad/juno>
* Bugs:   <http://github.com/minad/juno/issues>
* API documentation:
    * Latest Gem: <http://rubydoc.info/gems/juno/frames>
    * GitHub master: <http://rubydoc.info/github/minad/juno/master/frames>

Juno API
--------

~~~
#initialize(options)              options differs per-store, and is used to set up the store

#[](key)                          retrieve a key. if the key is not available, return nil

#load(key, options = {})          retrieve a key. if the key is not available, return nil

#fetch(key, options = {}, &block) retrieve a key. if the key is not available, execute the
                                  block and return its return value.

#fetch(key, value, options = {})  retrieve a key. if the key is not available, return the value

#[]=(key, value)                  set a value for a key. if the key is already used, clobber it.
                                  keys set using []= will never expire

#delete(key, options = {})        delete the key from the store and return the current value

#key?(key, options = {})          true if the key exists, false if it does not

#store(key, value, options = {})  same as []=, but you can supply options

#clear(options = {})              clear all keys in this store

#close                            close database connection
~~~

Creating a Store
----------------

There is a simple interface to create a store using `Juno.new`:

~~~ ruby
store = Juno.new(:Memcached, :server => 'localhost:11211')
~~~

If you want to have control over the proxies, you have to use `Juno.build`:

~~~ ruby
store = Juno.build do
  # Adds expires proxy
  use :Expires
  # Transform key using Marshal and Base64 and value using Marshal
  use :Transformer, :key => [:marshal, :base64], :value => :marshal
  # Memory backend
  adapter :Memory
end
~~~

Expiration
----------

The Cassandra, Memcached and Redis backends supports expires values directly:

~~~ ruby
cache = Juno::Adapters::Memcached.new

# Or using the builder...
cache = Juno.build do
  adapter :Memcached
end

# Expires in 60 seconds
cache.store(key, value, :expires => 60)
~~~

You can add the expires feature to other backends using the Expires proxy:

~~~ ruby
# Using the :expires option
cache = Juno.new(:File, :dir => '...', :expires => true)

# or manually by using the proxy...
cache = Juno::Expires.new(Juno::Adapters::File.new(:dir => '...'))

# or using the builder...
cache = Juno.build do
  use :Expires
  adapter :File, :dir => '...'
end
~~~

Framework Integration
---------------------

Inspired by [redis-store](https://github.com/jodosha/redis-store) there exist integration classes for Rack and Rack-Cache.

Use Juno as a Rack session store:

~~~ ruby
require 'rack/session/juno'

use Rack::Session::Juno, :store => :Redis
use Rack::Session::Juno, :store => Juno.new(:Memory, :expires => true)

use Rack::Session::Juno do
  use :Expires
  adapter :Memory
end
~~~

Use Juno as a Rack-Cache store:

~~~ ruby
require 'rack/cache/juno'

use Rack::Cache,
      :metastore   => 'juno://Memory?expires=true',
      :entitystore => 'juno://Memory?expires=true'

# Or used named Juno stores
Rack::Cache::Juno['named_metastore'] = Juno.build do
  use :Expires
  adapter :Memory
end
use Rack::Cache,
      :metastore => 'juno://named_metastore',
      :entity_store => 'juno://named_entitystore'
~~~

Use Juno to store cookies in Rack:

~~~ ruby
require 'rack/juno_cookies'

use Rack::JunoCookies, :domain => 'example.com', :path => '/path'
run lambda { |env|
  req = Rack::Request.new(env)
  req.cookies #=> is now a Juno store!!
  req.cookies['key'] #=> retrieves 'key'
  req.cookies['key'] = 'value' #=> sets 'key'
  req.cookies.delete('key') #=> removes 'key'
  [200,{},[]]
}
~~~

Alternatives
------------

* [Moneta](https://github.com/wycats/moneta): Juno is based on Moneta, but Juno supports more features and more backends and is actively developed
* [Horcrux](https://github.com/technoweenie/horcrux): Used at github, supports batch operations but only Memcached backend
* [ToyStore](https://github.com/jnunemaker/toystore): ORM mapper for key/value stores
* [ToyStore Adapter](https://github.com/jnunemaker/adapter): Adapter to key/value stores used by ToyStore, Juno can be used directly with the ToyStore Memory adapter

Authors
-------

* Daniel Mendler
* Hannes Georg
* Moneta originally by Yehuda Katz and contributors
