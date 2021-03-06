require 'spec_helper'

feature 'Dashboard > Activity' do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  context 'rss' do
    before do
      visit activity_dashboard_path
    end

    it_behaves_like "it has an RSS button with current_user's RSS token"
    it_behaves_like "an autodiscoverable RSS feed with current_user's RSS token"
  end

  context 'event filters', :js do
    let(:project) { create(:empty_project) }

    let(:merge_request) do
      create(:merge_request, author: user, source_project: project, target_project: project)
    end

    let(:push_event_data) do
      {
        before: Gitlab::Git::BLANK_SHA,
        after: '0220c11b9a3e6c69dc8fd35321254ca9a7b98f7e',
        ref: 'refs/heads/new_design',
        user_id: user.id,
        user_name: user.name,
        repository: {
          name: project.name,
          url: 'localhost/rubinius',
          description: '',
          homepage: 'localhost/rubinius',
          private: true
        }
      }
    end

    let(:note) { create(:note, project: project, noteable: merge_request) }

    let!(:push_event) do
      create(:event, :pushed, data: push_event_data, project: project, author: user)
    end

    let!(:merged_event) do
      create(:event, :merged, project: project, target: merge_request, author: user)
    end

    let!(:joined_event) do
      create(:event, :joined, project: project, author: user)
    end

    let!(:closed_event) do
      create(:event, :closed, project: project, target: merge_request, author: user)
    end

    let!(:comments_event) do
      create(:event, :commented, project: project, target: note, author: user)
    end

    before do
      project.add_master(user)

      visit activity_dashboard_path
      wait_for_requests
    end

    scenario 'user should see all events' do
      within '.content_list' do
        expect(page).to have_content('pushed new branch')
        expect(page).to have_content('joined')
        expect(page).to have_content('accepted')
        expect(page).to have_content('closed')
        expect(page).to have_content('commented on')
      end
    end

    scenario 'user should see only pushed events' do
      click_link('Push events')
      wait_for_requests

      within '.content_list' do
        expect(page).to have_content('pushed new branch')
        expect(page).not_to have_content('joined')
        expect(page).not_to have_content('accepted')
        expect(page).not_to have_content('closed')
        expect(page).not_to have_content('commented on')
      end
    end

    scenario 'user should see only merged events' do
      click_link('Merge events')
      wait_for_requests

      within '.content_list' do
        expect(page).not_to have_content('pushed new branch')
        expect(page).not_to have_content('joined')
        expect(page).to have_content('accepted')
        expect(page).not_to have_content('closed')
        expect(page).not_to have_content('commented on')
      end
    end

    scenario 'user should see only issues events' do
      click_link('Issue events')
      wait_for_requests

      within '.content_list' do
        expect(page).not_to have_content('pushed new branch')
        expect(page).not_to have_content('joined')
        expect(page).not_to have_content('accepted')
        expect(page).to have_content('closed')
        expect(page).not_to have_content('commented on')
      end
    end

    scenario 'user should see only comments events' do
      click_link('Comments')
      wait_for_requests

      within '.content_list' do
        expect(page).not_to have_content('pushed new branch')
        expect(page).not_to have_content('joined')
        expect(page).not_to have_content('accepted')
        expect(page).not_to have_content('closed')
        expect(page).to have_content('commented on')
      end
    end

    scenario 'user should see only joined events' do
      click_link('Team')
      wait_for_requests

      within '.content_list' do
        expect(page).not_to have_content('pushed new branch')
        expect(page).to have_content('joined')
        expect(page).not_to have_content('accepted')
        expect(page).not_to have_content('closed')
        expect(page).not_to have_content('commented on')
      end
    end

    scenario 'user see selected event after page reloading' do
      click_link('Push events')
      wait_for_requests
      visit activity_dashboard_path
      wait_for_requests

      within '.content_list' do
        expect(page).to have_content('pushed new branch')
        expect(page).not_to have_content('joined')
        expect(page).not_to have_content('accepted')
        expect(page).not_to have_content('closed')
        expect(page).not_to have_content('commented on')
      end
    end
  end
end
