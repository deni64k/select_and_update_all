require 'helper'

class TestEntry < ActiveRecord::Base
  @@before_called = 0
  @@after_called  = 0

  def self.before_called
    @@before_called
  end
  def self.after_called
    @@after_called
  end

  def before_update
    @@before_called += 1
    self.name = self.number.to_s if self.number_changed?
  end
  def after_update
    @@after_called += 1
  end
end

N = 10
(1..N).each {|i| TestEntry.create!(:name => i.to_s, :number => i ** 2) }

class TestSelectAndUpdateAll < ActiveSupport::TestCase
  context "with #{N} entries in test_entries" do
    should "have squares in test_entries.number" do
      squares = (1..N).map {|x| x ** 2 }

      numbers = TestEntry.all.map(&:number)
      assert_equal numbers.to_set, squares.to_set
      assert_equal numbers.size, squares.size
    end

    should "update all test_entries.number to id^3 with calling callbacks" do
      assert_difference 'TestEntry.before_called', N do
        assert_difference 'TestEntry.after_called', N do
          # Memprof.start
          TestEntry.select_and_update_all("number = id * id * id")
          # GC.start
          # Memprof.stats
          # Memprof.dump
          # Memprof.stop

          ids   = TestEntry.all.map(&:id)
          cubes = ids.map {|x| x ** 3}

          numbers = TestEntry.all.map(&:number)
          assert_equal numbers.to_set, cubes.to_set
          assert_equal numbers.size, cubes.size

          names = TestEntry.all.map(&:name).sort
          assert_equal names.to_set, cubes.map(&:to_s).to_set
          assert_equal names.size, cubes.size
        end
      end
    end

    should "update all test_entries.number to id^4 without calling callbacks" do
      assert_no_difference 'TestEntry.before_called' do
        assert_no_difference 'TestEntry.after_called' do
          names_was = TestEntry.all.map(&:name).sort

          TestEntry.update_all("number = id * id * id * id")
          ids    = TestEntry.all.map(&:id)
          tetras = ids.map {|x| x ** 4}

          numbers = TestEntry.all.map(&:number)
          assert_equal numbers.to_set, tetras.to_set
          assert_equal numbers.size, tetras.size

          names = TestEntry.all.map(&:name).sort
          assert_equal names.to_set, names_was.to_set
          assert_equal names.size, names_was.size
        end
      end
    end

    should "update a test_entries.number to id^5 with calling callbacks" do
      assert_difference 'TestEntry.before_called', 1 do
        assert_difference 'TestEntry.after_called', 1 do
          entry = TestEntry.last
          entry.number = entry.id ** 5
          entry.save

          entry.reload
          assert_equal entry.number, entry.id ** 5
          assert_equal entry.name, entry.number.to_s
        end
      end
    end
  end
end
