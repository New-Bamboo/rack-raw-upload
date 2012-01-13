module Rack
  class RawUpload
    module Helpers
      def put_file_in_hash( file_params, fake_file )
        # Add a param we can replace later
        params = Addressable::URI.new( :query => file_params+'=rawuploadsub' ).query_values
        # get the stack needed to rebuild the hash
        params = get_hash_stack( params, 'rawuploadsub' )
        # set file rebuilt hash
        set_in_hash( params, fake_file )
      end

      # builds an array of keys for hash reconstruction
      def get_hash_stack(hash, value)
        @stack ||= []
        hash.each do |k,v|
          @stack << k
          case v
            # Recusion
            when Hash;    get_hash_stack(v, value)
            # Stack is complete
            when String;  break if v == value
          end
        end
        @stack
      end

      # rebuilds hash with new end value
      def set_in_hash(stack, value)
        h    = {}
        walk = stack.length - 1
        # walk backwards creating hash with value
        walk.downto(0) do |i|
          h = {stack[i] => (i == walk)? value : h }
        end
        h
      end
    end

    module EqlFix
      def eql_with_fix?(o)
        self.object_id.eql?(o.object_id) || self.eql_without_fix?(o)
      end

      alias_method :eql_without_fix?, :eql?
      alias_method :eql?, :eql_with_fix?
    end
  end
end