# encoding: utf-8

require "spec_helper"

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")

describe Pose do
  subject { PosableOne.new }
  
  before :each do
    PosableOne.delete_all
    PosableTwo.delete_all
    PoseAssignment.delete_all
    PoseWord.delete_all
  end
  
  describe 'associations' do
    it 'allows to access the associated words of a posable object directly' do
      subject.should have(0).pose_words
      subject.pose_words << PoseWord.new(:text => 'one')
      subject.should have_pose_words(['one'])
    end
  end

  describe 'update_pose_index' do

    context "in the 'test' environment" do
      after :each do
        Pose::CONFIGURATION[:search_in_tests] = true
      end
      
      it "doesn't calls update_pose_words in tests if the test flag is not enabled" do
        Pose::CONFIGURATION[:search_in_tests] = false
        subject.should_not_receive :update_pose_words
        subject.update_pose_index
      end

      it "calls update_pose_words in tests if the test flag is enabled" do
        Pose::CONFIGURATION[:search_in_tests] = true
        subject.should_receive :update_pose_words
        subject.update_pose_index
      end
    end
    
    context "in the 'production' environment' do" do
      before :each do
        @old_env = Rails.env
        Rails.env = 'production'
      end
      
      after :each do
        Rails.env = @old_env
      end
      
      it "calls update_pose_words" do
        subject.should_receive :update_pose_words
        subject.update_pose_index
      end
    end
  end

  describe 'update_pose_words' do

    it 'saves the words for search' do
      subject.text = 'foo bar'
      subject.update_pose_words
      subject.should have(2).pose_words
      subject.should have_pose_words ['foo', 'bar']
    end

    it 'updates the search index when the text is changed' do
      subject.text = 'foo'
      subject.save!
      
      subject.text = 'other text'
      subject.update_pose_words

      subject.should have_pose_words ['other', 'text']
    end

    it "doesn't create duplicate words" do
      subject.text = 'foo foo'
      subject.save!
      subject.should have(1).pose_words
    end
  end

  describe 'get_words_to_remove' do

    it "returns an array of word objects that need to be removed" do
      word1 = PoseWord.new :text => 'one'
      word2 = PoseWord.new :text => 'two'
      existing_words = [word1, word2]
      new_words = ['one', 'three']

      result = Pose.get_words_to_remove existing_words, new_words

      result.should eql([word2])
    end

    it 'returns an empty array if there are no words to be removed' do
      word1 = PoseWord.new :text => 'one'
      word2 = PoseWord.new :text => 'two'
      existing_words = [word1, word2]
      new_words = ['one', 'two']

      result = Pose.get_words_to_remove existing_words, new_words

      result.should eql([])
    end
  end

  describe 'get_words_to_add' do

    it 'returns an array with strings that need to be added' do
      word1 = PoseWord.new :text => 'one'
      word2 = PoseWord.new :text => 'two'
      existing_words = [word1, word2]
      new_words = ['one', 'three']

      result = Pose.get_words_to_add existing_words, new_words

      result.should eql(['three'])
    end

    it 'returns an empty array if there is nothing to be added' do
      word1 = PoseWord.new :text => 'one'
      word2 = PoseWord.new :text => 'two'
      existing_words = [word1, word2]
      new_words = ['one', 'two']

      result = Pose.get_words_to_add existing_words, new_words

      result.should eql([])
    end
  end

  describe 'root_word' do

    it 'converts words into singular' do
      Pose.root_word('bars').should eql(['bar'])
    end

    it 'removes special characters' do
      Pose.root_word('(bar').should eql(['bar'])
      Pose.root_word('bar)').should eql(['bar'])
      Pose.root_word('(bar)').should eql(['bar'])
      Pose.root_word('>foo').should eql(['foo'])
      Pose.root_word('<foo').should eql(['foo'])
      Pose.root_word('"foo"').should eql(['foo'])
      Pose.root_word('"foo').should eql(['foo'])
      Pose.root_word("'foo'").should eql(['foo'])
      Pose.root_word("'foo's").should eql(['foo'])
      Pose.root_word("foo?").should eql(['foo'])
      Pose.root_word("foo!").should eql(['foo'])
      Pose.root_word("foo/bar").should eql(['foo', 'bar'])
      Pose.root_word("foo-bar").should eql(['foo', 'bar'])
      Pose.root_word("foo--bar").should eql(['foo', 'bar'])
      Pose.root_word("foo.bar").should eql(['foo', 'bar'])
    end

    it 'removes umlauts' do
      Pose.root_word('fünf').should eql(['funf'])
    end

    it 'splits up numbers' do
      Pose.root_word('11.2.2011').should eql(['11', '2', '2011'])
      Pose.root_word('11-2-2011').should eql(['11', '2', '2011'])
      Pose.root_word('30:4-5').should eql(['30', '4', '5'])
    end

    it 'converts into lowercase' do
      Pose.root_word('London').should eql(['london'])
    end

    it "stores single-letter words" do
      Pose.root_word('a b').should eql(['a', 'b'])
    end

    it "does't encode external URLs" do
      Pose.root_word('http://web.com').should eql(['http', 'web', 'com'])
    end

    it "doesn't store empty words" do
      Pose.root_word('  one two  ').should eql(['one', 'two'])
    end

    it "removes duplicates" do
      Pose.root_word('one_one').should eql(['one'])
      Pose.root_word('one one').should eql(['one'])
    end
    
    it "splits up complex URLs" do
      Pose.root_word('books?id=p7uyWPcVGZsC&dq=closure%20definitive%20guide&pg=PP1#v=onepage&q&f=false').should eql([
        "book", "id", "p7uywpcvgzsc", "dq", "closure", "definitive", "guide", "pg", "pp1", "v", "onepage", "q", "f", "false"])
    end
  end

  describe 'search' do
    
    it 'works' do
      pos1 = PosableOne.create :text => 'one'
      
      result = Pose.search 'one', PosableOne
      
      result.should have(1).items
      result[PosableOne].should have(1).items
      result[PosableOne][0].should == pos1
    end
    
    context 'classes parameter' do 
      it 'returns all different classes by default' do
        pos1 = PosableOne.create :text => 'foo'
        pos2 = PosableTwo.create :text => 'foo'
      
        result = Pose.search 'foo', [PosableOne, PosableTwo]
      
        result.should have(2).items
        result[PosableOne].should == [pos1]
        result[PosableTwo].should == [pos2]
      end
    
      it 'allows to provide different classes to return' do
        pos1 = PosableOne.create :text => 'foo'
        pos2 = PosableTwo.create :text => 'foo'
      
        result = Pose.search 'foo', [PosableOne, PosableTwo]
      
        result.should have(2).items
        result[PosableOne].should == [pos1]
        result[PosableTwo].should == [pos2]
      end
    
      it 'returns only instances of the given classes' do
        pos1 = PosableOne.create :text => 'one'
        pos2 = PosableTwo.create :text => 'one'
      
        result = Pose.search 'one', PosableOne
      
        result.should have(1).items
        result[PosableOne].should == [pos1]
      end
    end
    
    context 'query parameter' do

      it 'returns an empty array if nothing matches' do
        pos1 = PosableOne.create :text => 'one'

        result = Pose.search 'two', PosableOne

        result.should == { PosableOne => [] }
      end

      it 'returns only objects that match all given query words' do
        pos1 = PosableOne.create :text => 'one two'
        pos2 = PosableOne.create :text => 'one three'
        pos3 = PosableOne.create :text => 'two three'
      
        result = Pose.search 'two one', PosableOne
      
        result.should have(1).items
        result[PosableOne].should == [pos1]
      end
    
      it 'returns nothing if searching for a non-existing word' do
        pos1 = PosableOne.create :text => 'one two'
      
        result = Pose.search 'one zonk', PosableOne
      
        result.should have(1).items
        result[PosableOne].should == []
      end
    end
    
    context "'limit' parameter" do
      
      it 'works' do
        Factory :posable_one, :text => 'foo one'
        Factory :posable_one, :text => 'foo two'
        Factory :posable_one, :text => 'foo three'
        Factory :posable_one, :text => 'foo four'

        result = Pose.search 'foo', PosableOne, 3
        
        puts result.inspect
        result[PosableOne].should have(3).items
      end
    end
  end
end
