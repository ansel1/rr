require File.expand_path("#{File.dirname(__FILE__)}/../../../spec_helper")

module RR
  module Injections
    describe DoubleInjection do
      attr_reader :method_name, :double_injection

      macro("sets up subject and method_name") do
        it "sets up subject and method_name" do
          expect(double_injection.subject).to equal subject
          expect(double_injection.method_name).to eq method_name.to_sym
        end
      end

      subject { Object.new }

      describe "mock/stub" do
        context "when the subject responds to the injected method" do
          before do
            class << subject
              attr_reader :original_foobar_called

              def foobar
                @original_foobar_called = true
                :original_foobar
              end
            end

            expect(subject).to respond_to(:foobar)
            expect(!!subject.methods.detect {|method| method.to_sym == :foobar}).to be_true
            stub(subject).foobar {:new_foobar}
          end

          describe "being bound" do
            it "sets __rr__original_{method_name} to the original method" do
              expect(subject.__rr__original_foobar).to eq :original_foobar
            end

            describe "being called" do
              it "returns the return value of the block" do
                expect(subject.foobar).to eq :new_foobar
              end

              it "does not call the original method" do
                subject.foobar
                expect(subject.original_foobar_called).to be_nil
              end
            end

            describe "being reset" do
              before do
                RR::Space.reset_double(subject, :foobar)
              end

              it "rebinds the original method" do
                expect(subject.foobar).to eq :original_foobar
              end

              it "removes __rr__original_{method_name}" do
                subject.should_not respond_to(:__rr__original_foobar)
              end
            end
          end
        end

        context "when the subject does not respond to the injected method" do
          before do
            subject.should_not respond_to(:foobar)
            subject.methods.should_not include('foobar')
            stub(subject).foobar {:new_foobar}
          end

          it "does not set __rr__original_{method_name} to the original method" do
            subject.should_not respond_to(:__rr__original_foobar)
          end

          describe "being called" do
            it "calls the newly defined method" do
              expect(subject.foobar).to eq :new_foobar
            end
          end

          describe "being reset" do
            before do
              RR::Space.reset_double(subject, :foobar)
            end

            it "unsets the foobar method" do
              subject.should_not respond_to(:foobar)
              subject.methods.should_not include('foobar')
            end
          end
        end

        context "when the subject redefines respond_to?" do
          it "does not try to call the implementation" do
            class << subject
              def respond_to?(method_symbol, include_private = false)
                method_symbol == :foobar
              end
            end
            mock(subject).foobar
            expect(subject.foobar).to eq nil
          end
        end
      end

      describe "mock/stub + proxy" do
        context "when the subject responds to the injected method" do
          context "when the subject has the method defined" do
            describe "being bound" do
              before do
                def subject.foobar
                  :original_foobar
                end

                expect(subject).to respond_to(:foobar)
                expect(!!subject.methods.detect {|method| method.to_sym == :foobar}).to be_true
                stub.proxy(subject).foobar {:new_foobar}
              end

              it "aliases the original method to __rr__original_{method_name}" do
                expect(subject.__rr__original_foobar).to eq :original_foobar
              end

              it "replaces the original method with the new method" do
                expect(subject.foobar).to eq :new_foobar
              end

              describe "being called" do
                it "calls the original method first and sends it into the block" do
                  original_return_value = nil
                  stub.proxy(subject).foobar {|arg| original_return_value = arg; :new_foobar}
                  expect(subject.foobar).to eq :new_foobar
                  expect(original_return_value).to eq :original_foobar
                end
              end

              describe "being reset" do
                before do
                  RR::Space.reset_double(subject, :foobar)
                end

                it "rebinds the original method" do
                  expect(subject.foobar).to eq :original_foobar
                end

                it "removes __rr__original_{method_name}" do
                  subject.should_not respond_to(:__rr__original_foobar)
                end
              end
            end
          end

          context "when the subject does not have the method defined" do
            describe "being bound" do
              context "when the subject has not been previously bound to" do
                before do
                  setup_subject

                  expect(subject).to respond_to(:foobar)
                  stub.proxy(subject).foobar {:new_foobar}
                end

                def setup_subject
                  def subject.respond_to?(method_name)
                    if method_name.to_sym == :foobar
                      true
                    else
                      super
                    end
                  end
                end

                it "does not define __rr__original_{method_name}" do
                  subject.methods.should_not include("__rr__original_foobar")
                end

                context "when method is defined after being bound and before being called" do
                  def setup_subject
                    super
                    def subject.foobar
                      :original_foobar
                    end
                  end

                  describe "being called" do
                    it "defines __rr__original_{method_name} to be the lazily created method" do
                      expect((!!subject.methods.detect {|method| method.to_sym == :__rr__original_foobar})).to be_true
                      expect(subject.__rr__original_foobar).to eq :original_foobar
                    end

                    it "calls the original method first and sends it into the block" do
                      original_return_value = nil
                      stub.proxy(subject).foobar {|arg| original_return_value = arg; :new_foobar}
                      expect(subject.foobar).to eq :new_foobar
                      expect(original_return_value).to eq :original_foobar
                    end
                  end

                  describe "being reset" do
                    before do
                      RR::Space.reset_double(subject, :foobar)
                    end

                    it "rebinds the original method" do
                      expect(subject.foobar).to eq :original_foobar
                    end

                    it "removes __rr__original_{method_name}" do
                      subject.should_not respond_to(:__rr__original_foobar)
                    end
                  end
                end

                context "when method is still not defined" do
                  context "when the method is lazily created" do
                    def setup_subject
                      super
                      def subject.method_missing(method_name, *args, &block)
                        if method_name.to_sym == :foobar
                          def self.foobar
                            :original_foobar
                          end

                          foobar
                        else
                          super
                        end
                      end
                    end

                    describe "being called" do
                      it "defines __rr__original_{method_name} to be the lazily created method" do
                        subject.foobar
                        expect((!!subject.methods.detect {|method| method.to_sym == :__rr__original_foobar})).to be_true
                        expect(subject.__rr__original_foobar).to eq :original_foobar
                      end

                      it "calls the lazily created method and returns the injected method return value" do
                        original_return_value = nil
                        stub.proxy(subject).foobar {|arg| original_return_value = arg; :new_foobar}
                        expect(subject.foobar).to eq :new_foobar
                        expect(original_return_value).to eq :original_foobar
                      end
                    end

                    describe "being reset" do
                      context "when reset before being called" do
                        before do
                          RR::Space.reset_double(subject, :foobar)
                        end

                        it "rebinds the original method" do
                          expect(subject.foobar).to eq :original_foobar
                        end

                        it "removes __rr__original_{method_name}" do
                          subject.should_not respond_to(:__rr__original_foobar)
                        end
                      end
                    end
                  end

                  context "when the method is not lazily created (handled in method_missing)" do
                    def setup_subject
                      super
                      def subject.method_missing(method_name, *args, &block)
                        if method_name.to_sym == :foobar
                          :original_foobar
                        else
                          super
                        end
                      end
                    end

                    describe "being called" do
                      it "does not define the __rr__original_{method_name}" do
                        subject.foobar
                        subject.methods.should_not include("__rr__original_foobar")
                      end

                      it "calls the lazily created method and returns the injected method return value" do
                        original_return_value = nil
                        stub.proxy(subject).foobar {|arg| original_return_value = arg; :new_foobar}
                        expect(subject.foobar).to eq :new_foobar
                        expect(original_return_value).to eq :original_foobar
                      end
                    end

                    describe "being reset" do
                      before do
                        RR::Space.reset_double(subject, :foobar)
                      end

                      it "rebinds the original method" do
                        expect(subject.foobar).to eq :original_foobar
                      end

                      it "removes __rr__original_{method_name}" do
                        subject.should_not respond_to(:__rr__original_foobar)
                      end
                    end
                  end
                end
              end

              context "when the subject has been previously bound to" do
                before do
                  setup_subject

                  expect(subject).to respond_to(:foobar)
                  stub.proxy(subject).baz {:new_baz}
                  stub.proxy(subject).foobar {:new_foobar}
                end

                def setup_subject
                  def subject.respond_to?(method_name)
                    if method_name.to_sym == :foobar || method_name.to_sym == :baz
                      true
                    else
                      super
                    end
                  end
                end

                it "does not define __rr__original_{method_name}" do
                  subject.methods.should_not include("__rr__original_foobar")
                end

                context "when method is defined after being bound and before being called" do
                  def setup_subject
                    super
                    def subject.foobar
                      :original_foobar
                    end
                  end

                  describe "being called" do
                    it "defines __rr__original_{method_name} to be the lazily created method" do
                      expect((!!subject.methods.detect {|method| method.to_sym == :__rr__original_foobar})).to be_true
                      expect(subject.__rr__original_foobar).to eq :original_foobar
                    end

                    it "calls the original method first and sends it into the block" do
                      original_return_value = nil
                      stub.proxy(subject).foobar {|arg| original_return_value = arg; :new_foobar}
                      expect(subject.foobar).to eq :new_foobar
                      expect(original_return_value).to eq :original_foobar
                    end
                  end

                  describe "being reset" do
                    before do
                      RR::Space.reset_double(subject, :foobar)
                    end

                    it "rebinds the original method" do
                      expect(subject.foobar).to eq :original_foobar
                    end

                    it "removes __rr__original_{method_name}" do
                      subject.should_not respond_to(:__rr__original_foobar)
                    end
                  end
                end

                context "when method is still not defined" do
                  context "when the method is lazily created" do
                    def setup_subject
                      super
                      def subject.method_missing(method_name, *args, &block)
                        if method_name.to_sym == :foobar
                          def self.foobar
                            :original_foobar
                          end

                          foobar
                        else
                          super
                        end
                      end
                    end

                    describe "being called" do
                      it "defines __rr__original_{method_name} to be the lazily created method" do
                        subject.foobar
                        expect((!!subject.methods.detect {|method| method.to_sym == :__rr__original_foobar})).to be_true
                        expect(subject.__rr__original_foobar).to eq :original_foobar
                      end

                      it "calls the lazily created method and returns the injected method return value" do
                        original_return_value = nil
                        stub.proxy(subject).foobar {|arg| original_return_value = arg; :new_foobar}
                        expect(subject.foobar).to eq :new_foobar
                        expect(original_return_value).to eq :original_foobar
                      end
                    end

                    describe "being reset" do
                      context "when reset before being called" do
                        before do
                          RR::Space.reset_double(subject, :foobar)
                        end

                        it "rebinds the original method" do
                          expect(subject.foobar).to eq :original_foobar
                        end

                        it "removes __rr__original_{method_name}" do
                          subject.should_not respond_to(:__rr__original_foobar)
                        end
                      end
                    end
                  end

                  context "when the method is not lazily created (handled in method_missing)" do
                    def setup_subject
                      super
                      def subject.method_missing(method_name, *args, &block)
                        if method_name.to_sym == :foobar
                          :original_foobar
                        else
                          super
                        end
                      end
                    end

                    describe "being called" do
                      it "does not define the __rr__original_{method_name}" do
                        subject.foobar
                        subject.methods.should_not include("__rr__original_foobar")
                      end

                      it "calls the lazily created method and returns the injected method return value" do
                        original_return_value = nil
                        stub.proxy(subject).foobar {|arg| original_return_value = arg; :new_foobar}
                        expect(subject.foobar).to eq :new_foobar
                        expect(original_return_value).to eq :original_foobar
                      end
                    end

                    describe "being reset" do
                      before do
                        RR::Space.reset_double(subject, :foobar)
                      end

                      it "rebinds the original method" do
                        expect(subject.foobar).to eq :original_foobar
                      end

                      it "removes __rr__original_{method_name}" do
                        subject.should_not respond_to(:__rr__original_foobar)
                      end
                    end
                  end
                end
              end
            end
          end
        end

        context "when the subject does not respond to the injected method" do
          context "when the subject responds to the method via method_missing" do
            describe "being bound" do
              before do
                subject.should_not respond_to(:foobar)
                subject.methods.should_not include('foobar')
                class << subject
                  def method_missing(method_name, *args, &block)
                    if method_name == :foobar
                      :original_foobar
                    else
                      super
                    end
                  end
                end
                stub.proxy(subject).foobar {:new_foobar}
              end

              it "adds the method to the subject" do
                expect(subject).to respond_to(:foobar)
                expect((!!subject.methods.detect {|method| method.to_sym == :foobar})).to be_true
              end

              describe "being called" do
                it "calls the original method first and sends it into the block" do
                  original_return_value = nil
                  stub.proxy(subject).foobar {|arg| original_return_value = arg; :new_foobar}
                  expect(subject.foobar).to eq :new_foobar
                  expect(original_return_value).to eq :original_foobar
                end
              end

              describe "being reset" do
                before do
                  RR::Space.reset_double(subject, :foobar)
                end

                it "unsets the foobar method" do
                  subject.should_not respond_to(:foobar)
                  subject.methods.should_not include('foobar')
                end
              end
            end
          end

          context "when the subject would raise a NoMethodError when the method is called" do
            describe "being bound" do
              before do
                subject.should_not respond_to(:foobar)
                subject.methods.should_not include('foobar')
                stub.proxy(subject).foobar {:new_foobar}
              end

              it "adds the method to the subject" do
                expect(subject).to respond_to(:foobar)
                expect((!!subject.methods.detect {|method| method.to_sym == :foobar})).to be_true
              end

              describe "being called" do
                it "raises a NoMethodError" do
                  expect {
                    subject.foobar
                  }.to raise_error(NoMethodError)
                end
              end

              describe "being reset" do
                before do
                  RR::Space.reset_double(subject, :foobar)
                end

                it "unsets the foobar method" do
                  subject.should_not respond_to(:foobar)
                  subject.methods.should_not include('foobar')
                end
              end
            end
          end
        end
      end
    end
  end
end
