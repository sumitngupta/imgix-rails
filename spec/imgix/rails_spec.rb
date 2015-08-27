require 'spec_helper'
require 'rails'
require 'action_view'
require 'imgix/rails/view_helper'

describe Imgix::Rails do
  let(:truncated_version) { Imgix::Rails::VERSION.split(".").first(2).join(".") }
  let(:helper) do
    Class.new do
      include ActionView::Helpers::AssetTagHelper
      include ActionView::Helpers::TextHelper
      include Imgix::Rails::ViewHelper
      include ActionView::Context
    end.new
  end

  it 'has a version number' do
    expect(Imgix::Rails::VERSION).not_to be nil
  end

  it 'pulls in imgix-rb' do
    expect(Imgix::VERSION).not_to be nil
  end

  describe 'configuration' do
    let(:app) { Class.new(::Rails::Application) }
    let(:source) { "assets.imgix.net" }

    before do
      app.config.imgix = {}
    end

    it 'expects config.imgix.source to be defined' do
      expect{
        helper.ix_image_tag("assets.png")
      }.to raise_error(Imgix::Rails::ConfigurationError, "imgix source is not configured. Please set config.imgix[:source].")
    end

    it 'expects config.imgix.source to be a String or an Array' do
      app.config.imgix = { source: 1 }

      expect{
        helper.ix_image_tag("assets.png")
      }.to raise_error(Imgix::Rails::ConfigurationError, "imgix source must be a String or an Array.")
    end

    it 'optionally expects config.imgix.secure_url_token to be defined' do
      app.config.imgix = {
        source: 'assets.imgix.net',
        secure_url_token: 'FACEBEEF'
      }

      expect{
        helper.ix_image_tag("assets.png")
      }.not_to raise_error
    end

    describe 'hostname removal' do
      let(:hostname) { 's3.amazonaws.com' }
      let(:another_hostname) { 's3-us-west-2.amazonaws.com' }
      let(:yet_another_hostname) { 's3-sa-east-1.amazonaws.com' }
      let(:app) { Class.new(::Rails::Application) }
      let(:source) { "assets.imgix.net" }

      before do
        app.config.imgix = {
          source: source
        }
      end

      it 'does not remove a hostname for a fully-qualified URL' do
        app.config.imgix[:hostname_to_replace] = hostname

        expect(helper.ix_image_tag("https://adifferenthostname.com/image.jpg", w: 400, h: 300)).to eq "<img src=\"http://assets.imgix.net/https%3A%2F%2Fadifferenthostname.com%2Fimage.jpg?ixlib=rails-0.1.0&h=300&w=400\" alt=\"Https%3a%2f%2fadifferenthostname.com%2fimage.jpg?ixlib=rails 0.1\" />"
      end

      it 'removes a single hostname' do
        app.config.imgix[:hostname_to_replace] = hostname

        expect(helper.ix_image_tag("https://#{hostname}/image.jpg", w: 400, h: 300)).to eq "<img src=\"http://assets.imgix.net/image.jpg?ixlib=rails-0.1.0&h=300&w=400\" alt=\"Image.jpg?ixlib=rails 0.1\" />"
      end

      it 'removes multiple configured protocol/hostname combos' do
        app.config.imgix[:hostnames_to_replace] = [another_hostname, yet_another_hostname]

        expect(helper.ix_image_tag("https://#{another_hostname}/image.jpg", w: 400, h: 300)).to eq "<img src=\"http://assets.imgix.net/image.jpg?ixlib=rails-0.1.0&h=300&w=400\" alt=\"Image.jpg?ixlib=rails 0.1\" />"
        expect(helper.ix_image_tag("https://#{yet_another_hostname}/image.jpg", w: 400, h: 300)).to eq "<img src=\"http://assets.imgix.net/image.jpg?ixlib=rails-0.1.0&h=300&w=400\" alt=\"Image.jpg?ixlib=rails 0.1\" />"
      end
    end
  end

  describe Imgix::Rails::ViewHelper do
    let(:app) { Class.new(::Rails::Application) }
    let(:source) { "assets.imgix.net" }

    before do
      app.config.imgix = {
        source: source
      }
    end

    describe '#ix_image_tag' do
      it 'prints an image_tag' do
        expect(helper.ix_image_tag("image.jpg")).to eq  "<img src=\"http://assets.imgix.net/image.jpg?ixlib=rails-#{Imgix::Rails::VERSION}\" alt=\"Image.jpg?ixlib=rails #{truncated_version}\" />"
      end

      it 'signs image URLs with ixlib=rails' do
        expect(helper.ix_image_tag("image.jpg")).to include("ixlib=rails-")
      end

      it 'injects any imgix parameters given' do
        expect(helper.ix_image_tag("image.jpg", { w: 400, h: 300 })).to eq "<img src=\"http://assets.imgix.net/image.jpg?ixlib=rails-0.1.0&h=300&w=400\" alt=\"Image.jpg?ixlib=rails 0.1\" />"
      end

      it 'passes through non-imgix tags' do
        expect(helper.ix_image_tag("image.jpg", { alt: "No Church in the Wild", w: 400, h: 300 })).to eq "<img alt=\"No Church in the Wild\" src=\"http://assets.imgix.net/image.jpg?ixlib=rails-0.1.0&h=300&w=400\" />"
      end

      it 'signs an image path if a :secure_url_token is given' do
        app.config.imgix[:secure_url_token] = "FOO123bar"
        app.config.imgix[:include_library_param] = false
        expect(helper.ix_image_tag("/users/1.png")).to eq "<img src=\"http://assets.imgix.net/users/1.png?&s=3d97566c016f6e1e6679bf981941e6f4\" alt=\"1\" />"
      end
    end

    describe '#ix_responsive_image_tag' do
      let(:app) { Class.new(::Rails::Application) }
      let(:source) { "assets.imgix.net" }

      before do
        app.config.imgix = {
          source: source
        }
      end

      it 'generates a 1x and 2x image using `srcset` by default' do
        expect(helper.ix_responsive_image_tag("image.jpg")).to eq "<img srcset=\"http://assets.imgix.net/image.jpg?ixlib=rails-#{Imgix::Rails::VERSION} 1x, http://assets.imgix.net/image.jpg?ixlib=rails-#{Imgix::Rails::VERSION}&amp;dpr=2 2x\" src=\"http://assets.imgix.net/image.jpg?ixlib=rails-#{Imgix::Rails::VERSION}\" alt=\"Image.jpg?ixlib=rails #{truncated_version}\" />"
      end
    end

    describe '#ix_picture_tag' do
      it 'generates a picture tag' do
        expect(helper.ix_picture_tag("image.jpg")).to eq "<picture><source srcset=\"http://assets.imgix.net/image.jpg?ixlib=rails-#{Imgix::Rails::VERSION} 1x, http://assets.imgix.net/image.jpg?ixlib=rails-#{Imgix::Rails::VERSION}&amp;dpr=2 2x\" /><img src=\"http://assets.imgix.net/image.jpg?ixlib=rails-#{Imgix::Rails::VERSION}\" alt=\"Image.jpg?ixlib=rails #{truncated_version}\" /></picture>"
      end
    end
  end
end