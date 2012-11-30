require 'helper'

class PryNote::TestClass
  def ping
    binding
  end
end

def capture_exception
  ex = nil
  begin
    yield
  rescue Exception => e
    ex = e
  end
  ex
end

describe PryNote do
  before do
    Pad.obj = PryNote::TestClass.new
    @t = pry_tester
    PryNote.notes = {}
    Pry.config.notes_file = nil
  end

  after do
    Pad.clear
  end

  describe "note add" do
    describe "opens an editor when -m flag not provided" do
      it 'should open the editor' do
        used_editor = nil
        Pry.config.editor = proc { used_editor = true; nil }
        @t.process_command "note add PryNote::TestClass"
        used_editor.should == true
      end

      it 'should save the note' do
        Pry.config.editor = proc { nil }
        @t.process_command "note add PryNote::TestClass"
        PryNote.notes["PryNote::TestClass"].count.should == 1
      end

      it 'should put default note content in file' do
        Pry.config.editor = proc { nil }
        @t.process_command "note add PryNote::TestClass"
        PryNote.notes["PryNote::TestClass"].first.should =~ /Enter note content here/
      end
    end

    describe "explicit object" do
      it 'should add a new note for a method (bound method)' do
        @t.process_command "note add Pad.obj.ping -m 'my note'"
        @t.last_output.should =~ /Added note to PryNote::TestClass#ping/
        PryNote.notes["PryNote::TestClass#ping"].first.should =~ /my note/
      end

      it 'should add a new note for a method (unbound method)' do
        @t.process_command "note add PryNote::TestClass#ping -m 'my note'"
        @t.last_output.should =~ /Added note to PryNote::TestClass#ping/
        PryNote.notes["PryNote::TestClass#ping"].first.should =~ /my note/
      end

      it 'should add a new note for a class' do
        @t.process_command "note add PryNote::TestClass -m 'my note'"
        @t.last_output.should =~ /Added note to PryNote::TestClass/
        PryNote.notes["PryNote::TestClass"].first.should =~ /my note/
      end
    end

    describe "implicit object" do
      it 'should add a new note for class of object implicitly (without specifying object)' do
        @t.process_command "cd 0"
        @t.process_command "note add -m 'my note'"
        @t.last_output.should =~ /Added note to Fixnum/
        PryNote.notes["Fixnum"].first.should =~ /my note/
      end

      it 'should add a new note for a method implicitly (without specifying object)' do
        o = PryNote::TestClass.new
        t = pry_tester(o.ping)
        t.process_command "note add -m 'my note'"
        t.last_output.should =~ /Added note to PryNote::TestClass#ping/
        PryNote.notes["PryNote::TestClass#ping"].first.should =~ /my note/
      end
    end

    describe "multiple notes can be added" do
      it 'should add multiple notes' do
        @t.process_command "note add PryNote::TestClass -m 'my note1'"
        @t.process_command "note add PryNote::TestClass -m 'my note2'"
        PryNote.notes["PryNote::TestClass"].count.should == 2
        PryNote.notes["PryNote::TestClass"].first.should =~ /my note1/
        PryNote.notes["PryNote::TestClass"].last.should =~ /my note2/
      end
    end
  end

  describe "note delete" do
    it 'should delete all notes for an object' do
      @t.process_command "note add PryNote::TestClass -m 'my note'"
      PryNote.notes["PryNote::TestClass"].count.should == 1
      @t.process_command "note delete PryNote::TestClass"
      @t.last_output.should =~ /Deleted all notes for PryNote::TestClass/
      PryNote.notes["PryNote::TestClass"].should == nil
    end

    it 'should NOT delete notes for unspecified object' do
      @t.process_command "note add PryNote::TestClass -m 'my note'"
      @t.process_command "note add PryNote::TestClass#ping -m 'my note'"
      @t.process_command "note delete PryNote::TestClass"
      PryNote.notes["PryNote::TestClass#ping"].count.should == 1
    end

    it 'should delete all notes for all objects' do
      @t.process_command "note add PryNote::TestClass -m 'my note'"
      @t.process_command "note add PryNote::TestClass#ping -m 'my note'"
      PryNote.notes.keys.count.should == 2
      @t.process_command "note delete --all"
      @t.last_output.should =~ /Deleted all notes/
      PryNote.notes.empty?.should == true
    end

    describe "deleting specific notes for an object" do
      it 'should delete first note for an object' do
        @t.process_command "note add PryNote::TestClass -m 'my note1'"
        @t.process_command "note add PryNote::TestClass -m 'my note2'"
        PryNote.notes["PryNote::TestClass"].count.should == 2
        @t.process_command "note delete PryNote::TestClass:1"
        @t.last_output.should =~ /Deleted note 1 for PryNote::TestClass/
        PryNote.notes["PryNote::TestClass"].count.should == 1
        PryNote.notes["PryNote::TestClass"].first.should =~ /my note2/
      end

      it 'should delete middle note for an object' do
        @t.process_command "note add PryNote::TestClass -m 'my note1'"
        @t.process_command "note add PryNote::TestClass -m 'my note2'"
        @t.process_command "note add PryNote::TestClass -m 'my note3'"
        PryNote.notes["PryNote::TestClass"].count.should == 3
        @t.process_command "note delete PryNote::TestClass:2"
        @t.last_output.should =~ /Deleted note 2 for PryNote::TestClass/
        PryNote.notes["PryNote::TestClass"].count.should == 2
        PryNote.notes["PryNote::TestClass"].first.should =~ /my note1/
        PryNote.notes["PryNote::TestClass"].last.should =~ /my note3/
      end
    end
  end

  describe "note edit" do
    describe "errors" do
      it 'should error when not given a note number' do
        @t.process_command "note add PryNote::TestClass -m 'my note1'"

        capture_exception do
          @t.process_command "note edit PryNote::TestClass -m 'bing'"
        end.message.should =~ /Must specify a note number/
      end

      it 'should error when given out of range note number' do
        @t.process_command "note add PryNote::TestClass -m 'my note1'"

        capture_exception do
          @t.process_command "note edit PryNote::TestClass:2 -m 'bing'"
        end.message.should =~ /Invalid note number/
      end

      it 'should error when editing object with no notes' do
        capture_exception do
          @t.process_command "note edit PryNote::TestClass:2 -m 'bing'"
        end.message.should =~ /No notes to edit/
      end
    end

    describe "-m switch" do
      it 'should amend the content of a note' do
        @t.process_command "note add PryNote::TestClass -m 'my note1'"
        @t.process_command "note edit PryNote::TestClass:1 -m 'bing'"
        PryNote.notes["PryNote::TestClass"].count.should == 1
        PryNote.notes["PryNote::TestClass"].first.should =~ /bing/
      end
    end
  end

  describe "note export" do
    it 'should export to Pry.config.notes_file by default' do
      cleanup_file("bing.yml") do
        Pry.config.notes_file = "bing.yml"
        @t.process_command "note add PryNote::TestClass -m 'my note1'"
        @t.process_command "note add PryNote::TestClass -m 'my note2'"
        @t.process_command "note export"

        o = YAML.load(File.read("bing.yml"))
        o["PryNote::TestClass"].should == ['my note1', 'my note2']

        Pry.config.notes_file = nil
      end
    end

    it 'should export to specified file' do
      cleanup_file("blah.yml") do
        @t.process_command "note add PryNote::TestClass -m 'my note1'"
        @t.process_command "note add PryNote::TestClass -m 'my note2'"
        @t.process_command "note export blah.yml"
        o = YAML.load(File.read("blah.yml"))
        o["PryNote::TestClass"].should == ['my note1', 'my note2']
      end
    end
  end
end