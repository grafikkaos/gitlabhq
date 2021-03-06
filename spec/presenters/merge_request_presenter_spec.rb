require 'spec_helper'

describe MergeRequestPresenter do
  let(:resource) { create :merge_request, source_project: project }
  let(:project) { create :empty_project }
  let(:user) { create(:user) }

  describe '#ci_status' do
    subject { described_class.new(resource).ci_status }

    context 'when no head pipeline' do
      it 'return status using CiService' do
        ci_service = double(MockCiService)
        ci_status = double

        allow(resource.source_project)
          .to receive(:ci_service)
          .and_return(ci_service)

        allow(resource).to receive(:head_pipeline).and_return(nil)

        expect(ci_service).to receive(:commit_status)
          .with(resource.diff_head_sha, resource.source_branch)
          .and_return(ci_status)

        is_expected.to eq(ci_status)
      end
    end

    context 'when head pipeline present' do
      let(:pipeline) { build_stubbed(:ci_pipeline) }

      before do
        allow(resource).to receive(:head_pipeline).and_return(pipeline)
      end

      context 'success with warnings' do
        before do
          allow(pipeline).to receive(:success?) { true }
          allow(pipeline).to receive(:has_warnings?) { true }
        end

        it 'returns "success_with_warnings"' do
          is_expected.to eq('success_with_warnings')
        end
      end

      context 'pipeline HAS status AND its not success with warnings' do
        before do
          allow(pipeline).to receive(:success?) { false }
          allow(pipeline).to receive(:has_warnings?) { false }
        end

        it 'returns pipeline status' do
          is_expected.to eq('pending')
        end
      end

      context 'pipeline has NO status AND its not success with warnings' do
        before do
          allow(pipeline).to receive(:status) { nil }
          allow(pipeline).to receive(:success?) { false }
          allow(pipeline).to receive(:has_warnings?) { false }
        end

        it 'returns "preparing"' do
          is_expected.to eq('preparing')
        end
      end
    end
  end

  describe '#conflict_resolution_path' do
    let(:project) { create :empty_project }
    let(:user) { create :user }
    let(:presenter) { described_class.new(resource, current_user: user) }
    let(:path) { presenter.conflict_resolution_path }

    context 'when MR cannot be resolved in UI' do
      it 'does not return conflict resolution path' do
        allow(presenter).to receive_message_chain(:conflicts, :can_be_resolved_in_ui?) { false }

        expect(path).to be_nil
      end
    end

    context 'when conflicts cannot be resolved by user' do
      it 'does not return conflict resolution path' do
        allow(presenter).to receive_message_chain(:conflicts, :can_be_resolved_in_ui?) { true }
        allow(presenter).to receive_message_chain(:conflicts, :can_be_resolved_by?).with(user) { false }

        expect(path).to be_nil
      end
    end

    context 'when able to access conflict resolution UI' do
      it 'does return conflict resolution path' do
        allow(presenter).to receive_message_chain(:conflicts, :can_be_resolved_in_ui?) { true }
        allow(presenter).to receive_message_chain(:conflicts, :can_be_resolved_by?).with(user) { true }

        expect(path)
          .to eq("/#{project.full_path}/merge_requests/#{resource.iid}/conflicts")
      end
    end
  end

  context 'issues links' do
    let(:project) { create(:project, :private, creator: user, namespace: user.namespace) }
    let(:issue_a) { create(:issue, project: project) }
    let(:issue_b) { create(:issue, project: project) }

    let(:resource) do
      create(:merge_request,
             source_project: project, target_project: project,
             description: "Fixes #{issue_a.to_reference} Related #{issue_b.to_reference}")
    end

    before do
      project.team << [user, :developer]

      allow(resource.project).to receive(:default_branch)
        .and_return(resource.target_branch)
    end

    describe '#closing_issues_links' do
      subject { described_class.new(resource, current_user: user).closing_issues_links }

      it 'presents closing issues links' do
        is_expected.to match("#{project.full_path}/issues/#{issue_a.iid}")
      end

      it 'does not present related issues links' do
        is_expected.not_to match("#{project.full_path}/issues/#{issue_b.iid}")
      end

      it 'appends status when closing issue is already closed' do
        issue_a.close
        is_expected.to match('(closed)')
      end
    end

    describe '#mentioned_issues_links' do
      subject do
        described_class.new(resource, current_user: user)
          .mentioned_issues_links
      end

      it 'presents related issues links' do
        is_expected.to match("#{project.full_path}/issues/#{issue_b.iid}")
      end

      it 'does not present closing issues links' do
        is_expected.not_to match("#{project.full_path}/issues/#{issue_a.iid}")
      end

      it 'appends status when mentioned issue is already closed' do
        issue_b.close
        is_expected.to match('(closed)')
      end
    end

    describe '#assign_to_closing_issues_link' do
      subject do
        described_class.new(resource, current_user: user)
          .assign_to_closing_issues_link
      end

      before do
        assign_issues_service = double(MergeRequests::AssignIssuesService, assignable_issues: assignable_issues)
        allow(MergeRequests::AssignIssuesService).to receive(:new)
          .and_return(assign_issues_service)
      end

      context 'single closing issue' do
        let(:issue) { create(:issue) }
        let(:assignable_issues) { [issue] }

        it 'returns correct link with correct text' do
          is_expected
            .to match("#{project.full_path}/merge_requests/#{resource.iid}/assign_related_issues")

          is_expected
            .to match("Assign yourself to this issue")
        end
      end

      context 'multiple closing issues' do
        let(:issues) { create_list(:issue, 2) }
        let(:assignable_issues) { issues }

        it 'returns correct link with correct text' do
          is_expected
            .to match("#{project.full_path}/merge_requests/#{resource.iid}/assign_related_issues")

          is_expected
            .to match("Assign yourself to these issues")
        end
      end

      context 'no closing issue' do
        let(:assignable_issues) { [] }

        it 'returns correct link with correct text' do
          is_expected.to be_nil
        end
      end
    end
  end

  describe '#cancel_merge_when_pipeline_succeeds_path' do
    subject do
      described_class.new(resource, current_user: user)
        .cancel_merge_when_pipeline_succeeds_path
    end

    context 'when can cancel mwps' do
      it 'returns path' do
        allow(resource).to receive(:can_cancel_merge_when_pipeline_succeeds?)
          .with(user)
          .and_return(true)

        is_expected.to eq("/#{resource.project.full_path}/merge_requests/#{resource.iid}/cancel_merge_when_pipeline_succeeds")
      end
    end

    context 'when cannot cancel mwps' do
      it 'returns nil' do
        allow(resource).to receive(:can_cancel_merge_when_pipeline_succeeds?)
          .with(user)
          .and_return(false)

        is_expected.to be_nil
      end
    end
  end

  describe '#merge_path' do
    subject do
      described_class.new(resource, current_user: user).merge_path
    end

    context 'when can be merged by user' do
      it 'returns path' do
        allow(resource).to receive(:can_be_merged_by?)
          .with(user)
          .and_return(true)

        is_expected
          .to eq("/#{resource.project.full_path}/merge_requests/#{resource.iid}/merge")
      end
    end

    context 'when cannot be merged by user' do
      it 'returns nil' do
        allow(resource).to receive(:can_be_merged_by?)
          .with(user)
          .and_return(false)

        is_expected.to be_nil
      end
    end
  end

  describe '#create_issue_to_resolve_discussions_path' do
    subject do
      described_class.new(resource, current_user: user)
        .create_issue_to_resolve_discussions_path
    end

    context 'when can create issue and issues enabled' do
      it 'returns path' do
        allow(project).to receive(:issues_enabled?) { true }
        project.team << [user, :master]

        is_expected
          .to eq("/#{resource.project.full_path}/issues/new?merge_request_to_resolve_discussions_of=#{resource.iid}")
      end
    end

    context 'when cannot create issue' do
      it 'returns nil' do
        allow(project).to receive(:issues_enabled?) { true }

        is_expected.to be_nil
      end
    end

    context 'when issues disabled' do
      it 'returns nil' do
        allow(project).to receive(:issues_enabled?) { false }
        project.team << [user, :master]

        is_expected.to be_nil
      end
    end
  end

  describe '#remove_wip_path' do
    subject do
      described_class.new(resource, current_user: user).remove_wip_path
    end

    context 'when merge request enabled and has permission' do
      it 'has remove_wip_path' do
        allow(project).to receive(:merge_requests_enabled?) { true }
        project.team << [user, :master]

        is_expected
          .to eq("/#{resource.project.full_path}/merge_requests/#{resource.iid}/remove_wip")
      end
    end

    context 'when has no permission' do
      it 'returns nil' do
        is_expected.to be_nil
      end
    end
  end

  describe '#target_branch_commits_path' do
    subject do
      described_class.new(resource, current_user: user)
        .target_branch_commits_path
    end

    context 'when target branch exists' do
      it 'returns path' do
        allow(resource).to receive(:target_branch_exists?) { true }

        is_expected
          .to eq("/#{resource.target_project.full_path}/commits/#{resource.target_branch}")
      end
    end

    context 'when target branch does not exist' do
      it 'returns nil' do
        allow(resource).to receive(:target_branch_exists?) { false }

        is_expected.to be_nil
      end
    end
  end

  describe '#target_branch_tree_path' do
    subject do
      described_class.new(resource, current_user: user)
        .target_branch_tree_path
    end

    context 'when target branch exists' do
      it 'returns path' do
        allow(resource).to receive(:target_branch_exists?) { true }

        is_expected
          .to eq("/#{resource.target_project.full_path}/tree/#{resource.target_branch}")
      end
    end

    context 'when target branch does not exist' do
      it 'returns nil' do
        allow(resource).to receive(:target_branch_exists?) { false }

        is_expected.to be_nil
      end
    end
  end

  describe '#source_branch_path' do
    subject do
      described_class.new(resource, current_user: user).source_branch_path
    end

    context 'when source branch exists' do
      it 'returns path' do
        allow(resource).to receive(:source_branch_exists?) { true }

        is_expected
          .to eq("/#{resource.source_project.full_path}/branches/#{resource.source_branch}")
      end
    end

    context 'when source branch does not exist' do
      it 'returns nil' do
        allow(resource).to receive(:source_branch_exists?) { false }

        is_expected.to be_nil
      end
    end
  end

  describe '#source_branch_with_namespace_link' do
    subject do
      described_class.new(resource, current_user: user).source_branch_with_namespace_link
    end

    it 'returns link' do
      allow(resource).to receive(:source_branch_exists?) { true }

      is_expected
        .to eq("<a href=\"/#{resource.source_project.full_path}/tree/#{resource.source_branch}\">#{resource.source_branch}</a>")
    end
  end
end
