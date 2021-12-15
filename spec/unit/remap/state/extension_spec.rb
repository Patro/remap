# frozen_string_literal: true

RSpec::Matchers.define_negated_matcher :have_no_key, :have_key

xdescribe Remap::State::Extension do
  using Remap::Extensions::Enumerable
  using Remap::Extensions::Object
  using described_class

  describe "#ignore!" do
    let(:state) { defined! }

    context "when id exists" do
      let(:id) { :id1 }

      let(:state) { super().set(id: id) }

      context "when no pre-existing id's exists" do
        it "throws an error" do
          expect { state.ignore!("a reason") }.to throw_symbol(
            id, include(ids: be_empty).and(have_no_key(:id))
          )
        end
      end

      context "when pre-existing id's exists" do
        let(:id1) { id }
        let(:id2) { :id2 }
        let(:id3) { :id3 }

        let(:state) { super().merge(ids: [id2, id3]) }

        it "throws an error" do
          expect { state.ignore!("a reason") }.to throw_symbol(id1, include(ids: [id3], id: id2))
        end
      end
    end
  end

  describe "#notice" do
    context "when state is undefined" do
      subject { state.notice("%s", "a value") }

      let(:state) { undefined! }

      it { is_expected.to be_a(Remap::Notice) }
    end

    context "when state is defined" do
      subject { state.notice("%s", "a value") }

      let(:state) { defined! }

      it { is_expected.to be_a(Remap::Notice) }
    end
  end

  describe "#_" do
    context "when target is valid" do
      let(:state) { defined! }

      it "does not invoke block" do
        expect { |b| state._(&b) }.not_to yield_control
      end

      it "returns target" do
        expect(state._).to eq(state)
      end
    end

    context "when target is invalid" do
      let(:state) { defined!.except(:input) }

      it "invokes block" do
        expect { |b| state._(&b) }.to yield_control
      end
    end
  end

  describe "#only" do
    subject(:result) { target.only(*keys) }

    context "when keys are empty" do
      let(:target) { hash! }
      let(:keys)   { [] }

      it { is_expected.to be_empty }
    end

    context "when keys are not empty" do
      let(:keys) { [:a, :b] }

      context "when all keys exists" do
        let(:target) { { a: 1, b: 2 } }

        it { is_expected.to eq(target) }
      end

      context "when some keys exists" do
        let(:target) { { a: 1, c: 2 } }

        it { is_expected.to eq(target.except(:c)) }
      end

      context "when no keys exists" do
        let(:target) { { d: 1, e: 2 } }

        it { is_expected.to be_empty }
      end
    end
  end

  describe "#combine" do
    subject(:result) { left.combine(right) }

    context "when left is undefined!" do
      let(:left) { undefined!(:with_notices) }

      context "when right is undefined!" do
        let(:right) { undefined!(:with_notices) }

        it { is_expected.not_to have_key(:value) }
        its([:notices]) { is_expected.to have(2).items }
      end

      context "when right is defined!" do
        let(:right) { defined!(1, :with_notices) }

        it { is_expected.to contain(right.value) }
        its([:notices]) { is_expected.to have(2).items }
      end
    end

    context "when right is defined!" do
      let(:left) { defined!(:with_notices) }

      context "when right is undefined!" do
        let(:right) { undefined!(:with_notices) }

        it { is_expected.to contain(left.value) }
        its([:notices]) { is_expected.to have(1).item }
      end
    end

    context "when different types" do
      let(:left)  { defined!(10)     }
      let(:right) { defined!(:hello) }

      it "raises a fatal exception" do
        expect { result }.to raise_error(
          an_instance_of(Remap::Notice::Fatal).and(
            having_attributes(
              value: 10
            )
          )
        )
      end
    end

    context "when same type" do
      context "with same values" do
        let(:left) { defined!({ key: "value" })  }
        let(:right) { defined!({ key: "value" }) }

        it { is_expected.to include(value: { key: "value" }) }
      end

      context "when array" do
        let(:left) { defined!([1, 2]) }
        let(:right) { defined!([3, 4]) }

        it { is_expected.to include(value: contain_exactly(1, 2, 3, 4)) }
      end

      context "when hash" do
        let(:left) { defined!({ a: "A" }) }
        let(:right) { defined!({ b: "B" }) }

        it { is_expected.to contain({ a: "A", b: "B" }) }
      end
    end
  end

  describe "#map" do
    context "when state is undefined" do
      let(:state) { undefined! }

      it "does not invoke block" do
        expect { |iterator| state.map(&iterator) }.not_to yield_control
      end
    end

    context "when state is a hash" do
      let(:input) { { key1: "value1", key2: "value2" } }
      let(:state) { defined!(input) }

      context "when accessing value" do
        subject(:result) do
          state.map do |element|
            element.fmap do |value|
              value.upcase
            end
          end
        end

        it { is_expected.to contain(key1: "VALUE1", key2: "VALUE2") }
      end

      context "when accessing key" do
        subject(:result) do
          state.map do |element|
            element.fmap do |_value, state|
              state.key.upcase.to_s
            end
          end
        end

        it { is_expected.to contain(key1: "KEY1", key2: "KEY2") }
      end

      context "when iterator ignores some of the elements" do
        subject(:result) do
          state.map do |element|
            element.fmap do |value, state|
              case state.key
              in :key1
                value.upcase
              in :key2
                state.ignore!("Ignored!")
              end
            end
          end
        end

        it "raises a fatal exception" do
          expect { result }.to raise_error(
            an_instance_of(Remap::Notice::Ignore).and(
              having_attributes(
                reason: "Ignored!"
              )
            )
          )
        end
      end

      context "when iterator ignores all of the elements" do
        subject(:result) do
          state.map do |element|
            element.fmap do |_value, state|
              state.ignore!("Ignored!")
            end
          end
        end

        it "raises a fatal exception" do
          expect { result }.to raise_error(
            an_instance_of(Remap::Notice::Ignore).and(
              having_attributes(
                reason: "Ignored!"
              )
            )
          )
        end
      end
    end

    context "when state contains an array" do
      let(:input) { ["value1", "value2"] }
      let(:state) { defined!(input) }

      context "when accessing value" do
        subject(:result) do
          state.map do |element|
            element.fmap do |value|
              value.upcase
            end
          end
        end

        it { is_expected.to contain(["VALUE1", "VALUE2"]) }
      end

      context "when accessing index" do
        subject(:result) do
          state.map do |element|
            element.fmap do |_value, state|
              state.index
            end
          end
        end

        it { is_expected.to contain([0, 1]) }
      end

      context "when accessing element" do
        subject(:result) do
          state.map do |element|
            element.fmap do |_value, state|
              state.element.upcase
            end
          end
        end

        it { is_expected.to contain(["VALUE1", "VALUE2"]) }
      end

      context "when iterator ignores some of the elements" do
        subject(:result) do
          state.map do |element|
            element.fmap do |value, state|
              case state.index
              in 0
                value.upcase
              in 1
                state.ignore!("notice!")
              end
            end
          end
        end

        it "raises a fatal exception" do
          expect { result }.to raise_error(
            an_instance_of(Remap::Notice::Ignore).and(
              having_attributes(
                reason: "notice!"
              )
            )
          )
        end
      end

      context "when iterator ignores all of the elements" do
        subject(:result) do
          state.map do |element|
            element.fmap do |_, state|
              state.ignore!("notice!")
            end
          end
        end

        it "raises an ignore exception" do
          expect { result }.to raise_error(
            an_instance_of(Remap::Notice::Ignore).and(
              having_attributes(
                reason: "notice!"
              )
            )
          )
        end
      end
    end
  end

  describe "#failure" do
    subject { state.failure(reason) }

    let(:state) { state!(value, path: path, notices: notices) }
    let(:value)   { "value"                }
    let(:notices) { build_list(:notice, 1) }

    context "when state is without path" do
      let(:path) { [] }

      context "when reason is a string" do
        let(:reason) { "reason" }

        it { is_expected.to be_a(Remap::Failure) }
        it { is_expected.to have(1).failures }
        it { is_expected.to have(1).notices }

        its(:failures) { is_expected.to include(have_attributes(reason: "reason", path: path)) }
      end

      context "when reason is an array" do
        let(:reason) { ["reason1", "reason2"] }

        it { is_expected.to have(2).failures }
        it { is_expected.to have(1).notices }

        its(:failures) { is_expected.to include(have_attributes(reason: "reason1", path: path)) }
        its(:failures) { is_expected.to include(have_attributes(reason: "reason2", path: path)) }
      end

      context "when reason is a hash" do
        let(:reason) { { key1: ["error1", "error2"], key2: ["error3", "error4"] } }

        it { is_expected.to have(4).failures }
        it { is_expected.to have(1).notices }

        its(:failures) { is_expected.to include(have_attributes(reason: "error1", path: [:key1])) }
        its(:failures) { is_expected.to include(have_attributes(reason: "error2", path: [:key1])) }
        its(:failures) { is_expected.to include(have_attributes(reason: "error3", path: [:key2])) }
        its(:failures) { is_expected.to include(have_attributes(reason: "error4", path: [:key2])) }
      end
    end

    context "when state has path" do
      let(:path) { [:a, :b] }

      context "when reason is a string" do
        let(:reason) { "reason" }

        it { is_expected.to have(1).failures }
        it { is_expected.to have(1).notices }

        its(:failures) { is_expected.to include(have_attributes(reason: reason, path: path)) }
      end

      context "when reason is an array" do
        let(:reason) { ["reason1", "reason2"] }

        it { is_expected.to have(2).failures }
        it { is_expected.to have(1).notices }

        its(:failures) { is_expected.to include(have_attributes(reason: "reason1", path: path)) }
        its(:failures) { is_expected.to include(have_attributes(reason: "reason2", path: path)) }
      end

      context "when reason is a hash" do
        let(:reason) { { key1: ["error1", "error2"], key2: ["error3", "error4"] } }

        it { is_expected.to have(4).failures }
        it { is_expected.to have(1).notices }

        its(:failures) { is_expected.to include(have_attributes(reason: "error1", path: path + [:key1])) }
        its(:failures) { is_expected.to include(have_attributes(reason: "error2", path: path + [:key1])) }
        its(:failures) { is_expected.to include(have_attributes(reason: "error3", path: path + [:key2])) }
        its(:failures) { is_expected.to include(have_attributes(reason: "error4", path: path + [:key2])) }
      end
    end
  end

  describe "#tap" do
    context "when defined!" do
      let(:state) { defined!(10) }

      it "invokes block" do
        expect { |b| state.tap(&b) }.to yield_control
      end

      it "returns self" do
        expect(state.tap { :a_value }).to eq(state)
      end
    end
  end

  describe "#set" do
    let(:state) { defined! }
    let(:index) { 1        }
    let(:value) { "value"  }

    context "given an id" do
      subject { state.set(id: id1) }

      let(:id1) { :id1 }

      context "when state has no previous id" do
        its([:id]) { is_expected.to eq(id1) }
        its([:ids]) { is_expected.to be_empty }
      end

      context "when state already have an idea" do
        let(:id2)   { :id2 }
        let(:state) { defined!.set(id: id2) }

        its([:id]) { is_expected.to eq(id1) }
        its([:ids]) { is_expected.to eq([id2]) }
      end
    end

    context "when given an index" do
      subject(:result) { state.set(value, index: index) }

      it { is_expected.to include(index: index) }
      it { is_expected.to include(element: value) }
      it { is_expected.to contain(value) }
      it { is_expected.to include(path: state.path + [index]) }
    end

    context "when given a notice" do
      subject(:result) { state.set(notice: notice) }

      let(:notice) { notice! }

      it { is_expected.to include(notices: [notice]) }
      it { is_expected.to have_key(:value) }
    end

    context "when given a notice twice" do
      subject(:result) { state.set(notice: notice1).set(notice: notice2) }

      let(:notice1) { notice! }
      let(:notice2) { notice! }

      it { is_expected.to include(notices: [notice1, notice2]) }
      it { is_expected.to have_key(:value) }
    end

    context "when given just an index" do
      subject(:result) { state.set(index: index) }

      it { is_expected.to include(index: index) }
      it { is_expected.to include(path: state.path + [index]) }
    end

    context "when given a key" do
      subject(:result) { state.set(value, key: key) }

      let(:key) { :key }

      describe "#key" do
        subject { result.execute { key } }

        it { is_expected.to contain(key) }
        it { is_expected.to include(path: state.path + [key]) }
      end

      describe "#value" do
        subject { result.execute { value } }

        it { is_expected.to contain(value) }
      end
    end

    context "when given only a value" do
      subject(:result) { state.set(value) }

      describe "#value" do
        subject { result.execute { value } }

        it { is_expected.to contain(value) }
      end
    end

    context "when state is defined!" do
      subject(:result) { state.set(**options) }

      let(:state)  { defined! }
      let(:mapper) { mapper!  }

      context "when given a mapper" do
        let(:options) { { mapper: mapper } }

        it "copies #value to #scope" do
          expect(result).to include(scope: state.value)
        end
      end
    end

    context "when state is undefined!" do
      subject(:result) { state.set(**options) }

      let(:state)  { undefined! }
      let(:mapper) { mapper!    }

      context "when given a mapper" do
        let(:options) { { mapper: mapper } }

        it "does not copy #value to #scope" do
          expect(result).not_to have_key(:scope)
        end
      end
    end
  end

  describe "#include?" do
    context "when value is defined!" do
      subject { defined!(1) }

      it { is_expected.to contain(1) }
      it { is_expected.not_to contain(2) }
    end

    context "when value is undefined!" do
      subject { undefined! }

      it { is_expected.not_to have_key(:value) }
    end
  end

  describe "#execute" do
    context "when defined!" do
      subject { state.execute { |value| value + 1 } }

      let(:state) { defined!(1) }

      it { is_expected.to contain(2) }
    end

    context "when options are avalible" do
      subject { state.execute { name } }

      let(:state) { defined!(1, name: "Linus") }

      it { is_expected.to contain("Linus") }
    end

    context "when a state is not found" do
      subject(:result) do
        state.execute do
          does_not_exist
        end
      end

      let(:value) { value! }
      let(:state) { defined!(value) }

      it "raises a fatal exception" do
        expect { result }.to raise_error(
          an_instance_of(Remap::Notice::Ignore).and(
            having_attributes(
              value: value
            )
          )
        )
      end
    end

    context "when #values is accessed" do
      subject(:result) do
        state.execute do
          values == input
        end
      end

      let(:state) { state! }

      it { is_expected.to contain(true) }
    end

    context "when undefined!" do
      let(:state) { undefined! }

      it "does not invoke block" do
        expect { |block| state.execute(&block) }.not_to yield_control
      end
    end

    context "when skip! is called" do
      subject(:result) do
        state.execute { skip!("This is skipped!") }
      end

      let(:value) { "value" }
      let(:state) { defined!(value, path: [:key1]) }
      let(:notice) do
        { path: [:key1], reason: "This is skipped!", value: value }
      end

      it "raises a fatal exception" do
        expect { result }.to raise_error(
          an_instance_of(Remap::Notice::Ignore).and(
            having_attributes(
              path: [:key1],
              value: "value"
            )
          )
        )
      end
    end

    context "when #get is used" do
      context "when value exists" do
        subject(:result) do
          state.execute do
            value.get(:a, :b)
          end
        end

        let(:value) { { a: { b: "value" } } }
        let(:state) { defined!(value)       }

        it { is_expected.to contain("value") }
      end

      context "when value does not exists" do
        subject(:result) do
          state.execute do
            value.get(:a, :x)
          end
        end

        let(:state) { defined! }

        it "raises a fatal exception" do
          expect { result }.to raise_error(
            an_instance_of(Remap::Notice::Ignore).and(
              having_attributes(
                path: [:a]
              )
            )
          )
        end
      end
    end

    context "when KeyError is raised" do
      subject(:result) do
        state.execute do
          input.fetch(:does_not_exist)
        end
      end

      let(:value) { { key: "value" } }
      let(:state) { defined!(value)  }

      it "raises a ignore exception" do
        expect { result }.to raise_error(
          an_instance_of(Remap::Notice::Ignore).and(
            having_attributes(
              value: value
            )
          )
        )
      end
    end

    context "when IndexError is raised" do
      subject(:result) do
        state.execute do
          value.fetch(10)
        end
      end

      let(:value) { [1, 2, 3] }
      let(:state) { defined!(value) }

      it "raises a fatal exception" do
        expect { result }.to raise_error(
          an_instance_of(Remap::Notice::Ignore).and(
            having_attributes(
              value: value
            )
          )
        )
      end
    end
  end

  describe "#fmap" do
    context "when value is defined!" do
      let(:state) { defined!(1) }

      it "invokes block with value" do
        expect(state.fmap { |v| v + 1 }).to contain(2)
      end
    end

    context "when options are passed" do
      subject(:result) do
        state.fmap(key: key) do |&error|
          error["message"]
        end
      end

      let(:key)   { :key                       }
      let(:state) { defined!(value!, path: []) }

      it "raises a fatal exception" do
        expect { result }.to raise_error(
          an_instance_of(Remap::Notice::Ignore).and(
            having_attributes(
              path: [:key]
            )
          )
        )
      end
    end

    context "when value not defined!" do
      let(:state) { undefined! }

      it "invokes block with value" do
        expect { |block| state.fmap(&block) }.not_to yield_control
      end
    end

    context "when error block is invoked" do
      context "without pre-existing path" do
        subject(:result) do
          state.fmap do |_value, &error|
            error[reason]
          end
        end

        let(:state)  { defined! }
        let(:reason) { "reason" }

        it "raises a fatal exception" do
          expect { result }.to raise_error(
            an_instance_of(Remap::Notice::Ignore).and(
              having_attributes(
                reason: reason
              )
            )
          )
        end
      end

      context "with pre-existing path" do
        context "without key argument" do
          subject(:result) do
            state.fmap do
              state.ignore!(reason)
            end
          end

          let(:state) { defined!(1, path: [:key]) }
          let(:reason) { "reason" }

          it "raises a fatal exception" do
            expect { result }.to raise_error(
              an_instance_of(Remap::Notice::Ignore).and(
                having_attributes(
                  path: [:key],
                  reason: reason
                )
              )
            )
          end
        end

        context "with key argument" do
          subject(:result) do
            state.fmap(key: :key2) do |_value, &error|
              error[reason]
            end
          end

          let(:state) { defined!(1, path: [:key1]) }
          let(:reason) { "reason" }

          it "raises a fatal exception" do
            expect { result }.to raise_error(
              an_instance_of(Remap::Notice::Ignore).and(
                having_attributes(
                  path: [:key1, :key2],
                  reason: reason
                )
              )
            )
          end
        end
      end
    end
  end

  xdescribe "#bind" do
    context "when value is defined!" do
      let(:state) { defined!(1) }

      it "invokes block with value" do
        expect(state.bind { |v, s| s.set(v + 1) }).to contain(2)
      end
    end

    context "when value not defined!" do
      let(:state) { undefined! }

      it "invokes block with value" do
        expect { |block| state.bind(&block) }.not_to yield_control
      end

      it "returns itself" do
        expect(state.bind { raise "nope" }).to eq(state)
      end
    end

    context "when options are passed" do
      subject(:result) do
        state.bind(key: key) do |_value, _state, &error|
          error["error"]
        end
      end

      let(:key) { :key }
      let(:value) { "value"         }
      let(:state) { defined!(value) }

      it "raises a fatal exception" do
        expect { result }.to raise_error(
          an_instance_of(Remap::Notice::Ignore).and(
            having_attributes(
              path: [:key],
              value: value
            )
          )
        )
      end
    end

    context "when error block is invoked" do
      subject(:result) do
        state.bind do |&error|
          error[reason]
        end
      end

      let(:state) { defined! }
      let(:reason) { "reason" }

      it "raises a fatal exception" do
        expect { result }.to raise_error(
          an_instance_of(Remap::Notice::Ignore).and(
            having_attributes(
              reason: reason
            )
          )
        )
      end
    end
  end

  describe "#inspect" do
    subject { defined!.inspect }

    it { is_expected.to be_a(String) }
    it { is_expected.to include("#<State") }
  end

  describe "#paths" do
    context "when empty" do
      it "has no paths" do
        expect({}.paths).to eq([])
      end
    end

    context "when shallow" do
      it "has paths" do
        expect({ key: "value" }.paths).to eq([[:key]])
      end
    end

    context "when deep" do
      let(:input) do
        {
          shallow: "value",
          deep1: {
            deep2: "value"
          },
          deeper1: {
            deeper2: {
              deeper3: "value",
              deeper4: "value"
            },
            deeper5: {
              deeper6: "value"
            }
          }
        }.paths
      end

      it "has paths" do
        expect(input).to match_array([
          [:shallow],
          [:deep1, :deep2],
          [:deeper1, :deeper2, :deeper3],
          [:deeper1, :deeper2, :deeper4],
          [:deeper1, :deeper5, :deeper6]
        ])
      end
    end
  end
end
