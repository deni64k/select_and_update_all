require 'continuation' if RUBY_VERSION > '1.9'

module SelectAndUpdateAll
  def self.included(base)
    base.send :alias_method_chain, :update, :callbacks
  end

  def update_with_callbacks(*args)
    return false if callback(:before_update) == false
    kk = callcc { |k| return k }
    result = self.class.instance_method(:update_without_callbacks).bind(self).call(*args)
    kk = callcc { |k| kk.call(k) }
    callback(:after_update)
    kk.call(result)
  end
end

class ActiveRecord::Base
  def self.select_and_update_all(updates, conditions = nil, options = {})
    changed_fields = sanitize_sql_for_assignment(updates).split(', ').
      reduce({}) do |h, sql|
        sql =~ /([a-zA-Z0-9_]+)\s+=\s+(.*)/
        h[$1] = $2; h
      end

    model = model_name.constantize
    hash_for_select = model.column_names.reduce({}) do |h, name|
      h[name] = name; h
    end
    select_clause = changed_fields.reduce(hash_for_select) do |h, (field, value)|
      h["#{field}_new"] = value; h
    end.map do |field, value|
      "#{value} AS #{field}"
    end.join(', ')

    model.find_in_batches(options.merge({:select => select_clause, :conditions => conditions, :batch_size => 1000})) do |objs|
      objs.map! do |o|
        o.tap do |o|
          class << o
            include SelectAndUpdateAll
          end

          changed_fields.keys.each do |field|
            o.send("#{field}=", o.send("#{field}_new"))
          end
        end
      end

      # Run before callbacks.
      ks = objs.map {|o| o.send :update}

      # Undirty attributes the will be modified by update_all.
      objs.each do |o|
        changed_fields.keys.each do |field|
          (o.send :changed_attributes).delete(field)
        end
      end

      # Run actually update_all.
      # result = update_all(updates, conditions, options)
      result = update_all(updates, {:id => objs.map(&:id)}, options)

      # Run objects' update.
      ks.map! do |k|
        callcc do |kk|
          k.call(kk)
        end
      end

      # Run after callbacks.
      ks.map! do |k|
        callcc do |kk|
          k.call(kk)
        end
      end

      result
    end
  end
end
