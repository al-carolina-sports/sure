require "test_helper"

class DockerVersionStampTest < ActiveSupport::TestCase
  test "the image writes .sure-version from the SURE_VERSION build arg" do
    dockerfile = Rails.root.join("Dockerfile").read
    workflow = Rails.root.join(".github/workflows/publish.yml").read

    assert_includes dockerfile, "ARG SURE_VERSION"
    assert_includes dockerfile, "printf '%s\\n' \"$SURE_VERSION\" > /rails/.sure-version"
    assert_includes workflow, "SURE_VERSION=${{ needs.prepare.outputs.version }}"
  end
end
