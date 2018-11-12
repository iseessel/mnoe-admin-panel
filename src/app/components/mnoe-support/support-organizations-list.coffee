@App.directive('mnoeSupportOrganizationsList', ($filter, $translate, $state, $log, MnoeOrganizations, MnoeCurrentUser, MnoeUsers, MnoeAdminConfig, toastr) ->
  restrict: 'E',
  scope: {
    filterParams: '='
  },
  templateUrl: 'app/components/mnoe-support/support-organizations-list.html',
  link: (scope, elem) ->

    scope.isSupportRoleEnabled = MnoeAdminConfig.isSupportRoleEnabled()

    # Variables initialization
    scope.organizations =
      externalIdSearch: ''
      orgNameSearch: ''
      firstNameSearch: ''
      lastNameSearch: ''
      list: []

    scope.noResultsFound = () ->
      _.isEmpty(scope.organizations.list)

    MnoeCurrentUser.getUser().then(() ->
      scope.user = MnoeCurrentUser.user
    )

    scope.accessOrganizationInfo = (organization) ->
      scope.organizations.loading = true
      MnoeUsers.loginSupport(scope.user, organization.external_id).then(() ->
        scope.$emit('refreshDashboardLayoutSupport')
        $state.go('dashboard.customers.organization', { orgId: organization.id })
      ).catch((error) ->
        $log.error('Support cannot be logged in. Check if the org has an external id.', error)
        toastr.error('mnoe_admin_panel.dashboard.organization.widget.list.support.error')
      ).finally(() -> scope.organizations.loading = false)

    # table generation - need to get the locale first
    $translate(
      ["mnoe_admin_panel.dashboard.organization.account_frozen_state",
      "mnoe_admin_panel.dashboard.organization.widget.list.table.creation",
      'mnoe_admin_panel.dashboard.organization.widget.list.table.name',
      "mnoe_admin_panel.dashboard.organization.demo_account_state"])
      .then((locale) ->
        # create the fields for the sortable-table
        scope.organizations.fields = [
          # organization name
          { header: locale['mnoe_admin_panel.dashboard.organization.widget.list.table.name']
          attr: 'name'
          doNotSort: true
          render: (organization) ->
            template: """
              <a ui-sref="dashboard.customers.organization({orgId: organization.id})">
                {{::organization.name}}
                <em ng-show="organization.account_frozen" class="text-muted" translate>
                mnoe_admin_panel.dashboard.organization.account_frozen_state</em>
                <em ng-show="organization.demo_account" class="text-muted" translate>
                mnoe_admin_panel.dashboard.organization.demo_account_state</em>
              </a>
            """,
            scope: {
              organization: organization
              }
            }

          # organization creation date
          { header: locale["mnoe_admin_panel.dashboard.organization.widget.list.table.creation"],
          style: {width: '110px'},
          attr:'created_at',
          doNotSort: true
          render: (organization) ->
            template:
              "<span>{{::organization.created_at | amDateFormat:'L'}}</span>"
            scope: {organization: organization}}
        ]
      )

    scope.externalIdSearch = () ->
      # Reset other search fields.
      scope.organizations.orgNameSearch = ''
      scope.organizations.firstNameSearch = ''
      scope.organizations.lastNameSearch = ''
      setSearchOrganizationsList()

    scope.nameSearch = () ->
      org = scope.organizations
      # Reset other search field.
      scope.organizations.externalIdSearch = ''
      setSearchOrganizationsList()

    scope.noResultsText = if scope.isSupportRoleEnabled
      "mnoe_admin_panel.dashboard.organization.widget.list.suport.search_users.no_results"
    else
      "mnoe_admin_panel.dashboard.organization.widget.list.suport.search_users.support_role_disabled"

    # Display only the search results
    setSearchOrganizationsList = () ->
      params = searchParams()
      return scope.organizations.list = [] unless params

      scope.organizations.loading = true
      MnoeOrganizations.supportSearch(params).then((response) ->
        scope.organizations.list = $filter('orderBy')(response.data.organizations, 'created_at')
      ).finally(-> scope.organizations.loading = false)


    searchParams = () ->
      searchNameTerms = [scope.organizations.firstNameSearch, scope.organizations.lastNameSearch, scope.organizations.orgNameSearch]
      if searchByOrgExternalId()
        externalIdSearch()
      # If all search terms are present, search partially if each character is greater than 3.
      else if searchByUserNameAndOrgName()
        if meetsMinLength(searchNameTerms, 3) then partialNameSearch() else exactUserNameSearch()
      else if searchByUserName()
        searchNameTerms.splice(-1)
        if meetsMinLength(searchNameTerms, 4) then partialNameSearch() else exactUserNameSearch()
      else
        # Invalid search, do not attempt to search.
        return false

    searchByUserName = () ->
      scope.organizations.firstNameSearch && scope.organizations.lastNameSearch

    searchByUserNameAndOrgName = () ->
      searchByUserName() && scope.organizations.orgNameSearch

    searchByOrgExternalId = () ->
      scope.organizations.externalIdSearch

    meetsMinLength = (arr, minLength) ->
      arr.every((el) ->
        el && el.length >= minLength
      )

    externalIdSearch = () ->
      org_search:
        where:
          external_id: scope.organizations.externalIdSearch

    partialNameSearch = () ->
      org_search:
        where:
          'name.like': "%#{scope.organizations.orgNameSearch}%"
      user_search:
        where:
          'name.like': "%#{scope.organizations.firstNameSearch}%"
          'surname.like': "%#{scope.organizations.lastNameSearch}%"

    exactUserNameSearch = () ->
      org_search:
        where:
          name: "#{scope.organizations.orgNameSearch}"
      user_search:
        where:
          name: "#{scope.organizations.firstNameSearch}"
          surname: "#{scope.organizations.lastNameSearch}"
)
