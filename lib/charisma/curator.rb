require 'set'
require 'forwardable'
module Charisma
  # A Hash-like object that stores computed characteristics about an instance of a characterized class.
  #
  # Every instance of a characterized class gets a Curator, accessed via <tt>#characteristics</tt>.
  # @see Charisma::Base#characteristics
  class Curator
    # The curator's subject--the instance itself' 
    attr_reader :subject
    
    # Create a Curator.
    #
    # Typically this is done automatically when <tt>#characteristics</tt> is called on an instance of a characterized class for the first time.
    # @param [Object] The subject of the curation -- an instance of a characterized class
    # @see Charisma::Base#characteristics
    def initialize(subject)
      @subject = subject
      subject.class.characterization.keys.each do |key|
        if subject.respond_to?(key)
          value = subject.send(key)
          self[key] = value unless value.nil?
        end
      end
    end

    # The special hash wrapped by the curator that actually stores the computed characteristics.
    def characteristics
      return @characteristics if @characteristics

      hsh = Hash.new do |_, key|
        if characterization = subject.class.characterization[key]
          Curation.new nil, characterization
        end
      end
      hsh.extend LooseEquality
      @characteristics = hsh
    end
    
    # Store a late-defined characteristic, with a Charisma wrapper.
    # @param [Symbol] key The name of the characteristic, which must match one defined in the class's characterization
    # @param value The value of the characteristic
    def []=(key, value)
      characteristics[key] = Curation.new value, subject.class.characterization[key]
    end
    
    # A custom inspection method to enhance IRB and log readability
    def inspect
      "<Charisma:Curator #{keys.length} known characteristic(s)>"
    end
    
    # (see #inpsect)
    def to_s; inspect end
    
    # Provide a hash of the plain values (dropping presentation information).
    #
    # Previous versions of leap returned a hash of display-friendly representations; this was rather surprising and not especially useful.
    # @return [Hash]
    def to_hash
      characteristics.inject({}) do |memo, (k, v)|
        memo[k] = v.value
        memo
      end
    end
    
    # Provide a shallow copy.
    #
    # @return [Charisma::Curator]
    def dup
      shallow = super
      shallow.instance_variable_set :@characteristics, characteristics.dup
      shallow
    end

    def marshal_dump
      [@subject, to_hash]
    end

    def marshal_load(src)
      @subject, hsh = src
      hsh.each do |k, v|
        self[k] = v
      end
    end
    
    extend ::Forwardable
    def_delegators :characteristics, :[], :keys, :slice, :hash, :==, :each
    
    # Loose equality for Hashlike objects
    #
    # <tt>Hash#==</tt> as defined in Ruby core is very, very strict: it uses <tt>Object#==</tt> on each of its values to determine equality.
    # This module overrides <tt>#==</tt> to loosen this evaluation.
    module LooseEquality
      # Determine equality with another Hashlike object, loosely.
      #
      # Unlike Ruby's own <tt>Hash#==</tt>, this method uses the values' native <tt>#==</tt> methods, where available, to determine equality.
      # @param [Hash] other The other hash
      #
      # @private
      # to_set is faster than sort_by (and much faster than sort)
      # 1.9.3p125 :011 > f = ('a'..'zz').to_a.map(&:to_sym).sort_by { rand }; require 'benchmark'; require 'set'; Benchmark.realtime { 10_000.times { f.sort } }
      # => 27.306745 
      # 1.9.3p125 :012 > f = ('a'..'zz').to_a.map(&:to_sym).sort_by { rand }; require 'benchmark'; require 'set'; Benchmark.realtime { 10_000.times { f.sort_by { |k| k.to_s } } }
      # => 6.176923 
      # 1.9.3p125 :013 > f = ('a'..'zz').to_a.map(&:to_sym).sort_by { rand }; require 'benchmark'; require 'set'; Benchmark.realtime { 10_000.times { f.to_set } }
      # => 3.377742 
      def ==(other)
        return false unless keys.to_set == other.keys.to_set
        keys.all? do |k|
          self[k] == other[k]
        end
      end
    end
  end
end
