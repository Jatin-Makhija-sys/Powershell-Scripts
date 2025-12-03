function New-IGHtmlDashboard {
    param(
        [Parameter(Mandatory)]
        [psobject]$Inventory,
        [Parameter(Mandatory)]
        [string]$OutputPath,
        [string]$TenantId
    )

    $inventoryJson = $Inventory | ConvertTo-Json -Depth 8
    $generatedOn = Get-Date -Format 'yyyy-MM-dd HH:mm'

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>Intune Inventory Report</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/dataTables.bootstrap5.min.css">
    <style>
        body { padding: 20px; background-color: #f5f6fa; }
        h1 { font-size: 1.8rem; }
        .card-metric { min-width: 180px; border-radius: 1rem; }
        .card-metric h3 { font-size: 1.6rem; }
        .chart-container { position: relative; height: 320px; }
        .tab-content { margin-top: 15px; }
        .navbar-brand { font-weight: 600; }
        .table thead th { white-space: nowrap; }
    </style>
</head>
<body>
    <div class="container-fluid">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <div>
                <h1 class="mb-0">Intune Inventory Report</h1>
                <small class="text-muted">Tenant: $TenantId&nbsp;&nbsp;|&nbsp;&nbsp;Generated: $generatedOn</small>
            </div>
        </div>

        <!-- Summary metrics -->
        <div class="row g-3 mb-3">
            <div class="col-md-3">
                <div class="card card-metric shadow-sm">
                    <div class="card-body">
                        <h6 class="card-subtitle text-muted">Managed devices</h6>
                        <h3 id="metricDevices" class="card-title fw-bold">0</h3>
                        <small class="text-muted">Across all platforms</small>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card card-metric shadow-sm">
                    <div class="card-body">
                        <h6 class="card-subtitle text-muted">Users</h6>
                        <h3 id="metricUsers" class="card-title fw-bold">0</h3>
                        <small class="text-muted">Enabled directory users</small>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card card-metric shadow-sm">
                    <div class="card-body">
                        <h6 class="card-subtitle text-muted">Policies</h6>
                        <h3 id="metricPolicies" class="card-title fw-bold">0</h3>
                        <small class="text-muted">Config + compliance policies</small>
                    </div>
                </div>
            </div>
            <div class="col-md-3">
                <div class="card card-metric shadow-sm">
                    <div class="card-body">
                        <h6 class="card-subtitle text-muted">Apps</h6>
                        <h3 id="metricApps" class="card-title fw-bold">0</h3>
                        <small class="text-muted">Managed apps</small>
                    </div>
                </div>
            </div>
        </div>

        <!-- Charts -->
        <div class="row g-3 mb-3">
            <div class="col-md-6">
                <div class="card shadow-sm h-100">
                    <div class="card-header">Devices by platform</div>
                    <div class="card-body">
                        <div class="chart-container">
                            <canvas id="chartDevicesByOs"></canvas>
                        </div>
                    </div>
                </div>
            </div>
            <div class="col-md-6">
                <div class="card shadow-sm h-100">
                    <div class="card-header">Device compliance state</div>
                    <div class="card-body">
                        <div class="chart-container">
                            <canvas id="chartCompliance"></canvas>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Tabs -->
        <ul class="nav nav-tabs" id="mainTabs" role="tablist">
            <li class="nav-item" role="presentation">
                <button class="nav-link active" id="tab-devices-tab" data-bs-toggle="tab" data-bs-target="#tab-devices" type="button" role="tab">Devices</button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="tab-config-tab" data-bs-toggle="tab" data-bs-target="#tab-config" type="button" role="tab">Config policies</button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="tab-compliance-tab" data-bs-toggle="tab" data-bs-target="#tab-compliance" type="button" role="tab">Compliance policies</button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="tab-apps-tab" data-bs-toggle="tab" data-bs-target="#tab-apps" type="button" role="tab">Apps</button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="tab-groups-tab" data-bs-toggle="tab" data-bs-target="#tab-groups" type="button" role="tab">Groups</button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="tab-assignments-tab" data-bs-toggle="tab" data-bs-target="#tab-assignments" type="button" role="tab">Assignments and mappings</button>
            </li>
            <li class="nav-item" role="presentation">
                <button class="nav-link" id="tab-unassigned-tab" data-bs-toggle="tab" data-bs-target="#tab-unassigned" type="button" role="tab">Unassigned policies</button>
            </li>
        </ul>

        <div class="tab-content" id="mainTabsContent">
            <div class="tab-pane fade show active" id="tab-devices" role="tabpanel">
                <div class="mt-3">
                    <table id="tblDevices" class="table table-sm table-striped table-hover w-100"></table>
                </div>
            </div>
            <div class="tab-pane fade" id="tab-config" role="tabpanel">
                <div class="mt-3">
                    <table id="tblConfig" class="table table-sm table-striped table-hover w-100"></table>
                </div>
            </div>
            <div class="tab-pane fade" id="tab-compliance" role="tabpanel">
                <div class="mt-3">
                    <table id="tblCompliance" class="table table-sm table-striped table-hover w-100"></table>
                </div>
            </div>
            <div class="tab-pane fade" id="tab-apps" role="tabpanel">
                <div class="mt-3">
                    <table id="tblApps" class="table table-sm table-striped table-hover w-100"></table>
                </div>
            </div>
            <div class="tab-pane fade" id="tab-groups" role="tabpanel">
                <div class="mt-3">
                    <table id="tblGroups" class="table table-sm table-striped table-hover w-100"></table>
                </div>
            </div>
            <div class="tab-pane fade" id="tab-assignments" role="tabpanel">
                <div class="mt-3">
                    <div class="row mb-2">
                        <div class="col-md-4">
                            <label for="groupFilter" class="form-label">Filter by group</label>
                            <select id="groupFilter" class="form-select form-select-sm">
                                <option value="">Show all assignments</option>
                            </select>
                        </div>
                    </div>
                    <table id="tblAssignments" class="table table-sm table-striped table-hover w-100"></table>
                </div>
            </div>
            <div class="tab-pane fade" id="tab-unassigned" role="tabpanel">
                <div class="mt-3">
                    <table id="tblUnassigned" class="table table-sm table-striped table-hover w-100"></table>
                </div>
            </div>
        </div>

        <hr class="mt-4" />
        <small class="text-muted">
            Report generated using Microsoft Graph. Data is point in time and may not reflect later changes.
        </small>
    </div>

    <!-- Raw JSON payload -->
    <script id="invData" type="application/json">
$inventoryJson
    </script>

    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.8/js/dataTables.bootstrap5.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>

    <script>
        const inventory = JSON.parse(document.getElementById('invData').textContent);

        function groupBy(array, selector) {
            const result = {};
            if (!array) { return result; }
            array.forEach(function (item) {
                const key = selector(item);
                if (!key) { return; }
                if (!result[key]) { result[key] = 0; }
                result[key] = result[key] + 1;
            });
            return result;
        }

        function initMetrics() {
            document.getElementById('metricDevices').innerText = inventory.Devices.length;
            document.getElementById('metricUsers').innerText = inventory.Users.length;
            document.getElementById('metricPolicies').innerText = inventory.ConfigPolicies.length + inventory.CompliancePolicies.length;
            document.getElementById('metricApps').innerText = inventory.Apps.length;
        }

        function initCharts() {
            const devicesByOs = groupBy(inventory.Devices, function (d) { return d.OperatingSystem; });
            const osLabels = Object.keys(devicesByOs);
            const osCounts = Object.values(devicesByOs);

            if (osLabels.length > 0) {
                new Chart(document.getElementById('chartDevicesByOs'), {
                    type: 'pie',
                    data: {
                        labels: osLabels,
                        datasets: [{
                            data: osCounts
                        }]
                    },
                    options: {
                        plugins: {
                            legend: {
                                position: 'bottom'
                            }
                        }
                    }
                });
            }

            const devicesByCompliance = groupBy(inventory.Devices, function (d) { return d.ComplianceState; });
            const compLabels = Object.keys(devicesByCompliance);
            const compCounts = Object.values(devicesByCompliance);

            if (compLabels.length > 0) {
                new Chart(document.getElementById('chartCompliance'), {
                    type: 'doughnut',
                    data: {
                        labels: compLabels,
                        datasets: [{
                            data: compCounts
                        }]
                    },
                    options: {
                        plugins: {
                            legend: {
                                position: 'bottom'
                            }
                        }
                    }
                });
            }
        }

        function initDataTable(selector, columns, data) {
            jQuery(selector).DataTable({
                data: data,
                columns: columns,
                paging: true,
                pageLength: 25,
                lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, 'All']],
                stateSave: true,
                deferRender: true,
                autoWidth: false
            });
        }

        function initTables() {
            initDataTable('#tblDevices', [
                { title: 'Device name', data: 'DeviceName' },
                { title: 'User', data: 'UserPrincipalName' },
                { title: 'Owner type', data: 'ManagedDeviceOwnerType' },
                { title: 'OS', data: 'OperatingSystem' },
                { title: 'OS version', data: 'OsVersion' },
                { title: 'Compliance', data: 'ComplianceState' },
                { title: 'Management agent', data: 'ManagementAgent' },
                { title: 'Last sync', data: 'LastSyncDateTime' },
                { title: 'Enrolled', data: 'EnrolledDateTime' },
                { title: 'Serial number', data: 'SerialNumber' }
            ], inventory.Devices);

            initDataTable('#tblConfig', [
                { title: 'Name', data: 'DisplayName' },
                { title: 'Type', data: 'PolicyType' },
                { title: 'Platform', data: 'Platform' },
                { title: 'Description', data: 'Description' },
                { title: 'Created', data: 'CreatedDateTime' },
                { title: 'Modified', data: 'LastModifiedDateTime' },
                { title: 'Assignments', data: 'AssignmentCount' }
            ], inventory.ConfigPolicies);

            initDataTable('#tblCompliance', [
                { title: 'Name', data: 'DisplayName' },
                { title: 'Platform', data: 'Platform' },
                { title: 'Description', data: 'Description' },
                { title: 'Created', data: 'CreatedDateTime' },
                { title: 'Modified', data: 'LastModifiedDateTime' },
                { title: 'Assignments', data: 'AssignmentCount' }
            ], inventory.CompliancePolicies);

            initDataTable('#tblApps', [
                { title: 'Name', data: 'DisplayName' },
                { title: 'Publisher', data: 'Publisher' },
                { title: 'App type', data: 'AppType' },
                { title: 'Is featured', data: 'IsFeatured' },
                { title: 'Created', data: 'CreatedDateTime' },
                { title: 'Modified', data: 'LastModifiedDateTime' },
                { title: 'Assignments', data: 'AssignmentCount' }
            ], inventory.Apps);

            initDataTable('#tblGroups', [
                { title: 'Name', data: 'DisplayName' },
                { title: 'Description', data: 'Description' },
                { title: 'Mail nickname', data: 'MailNickname' },
                { title: 'Mail enabled', data: 'MailEnabled' },
                { title: 'Security enabled', data: 'SecurityEnabled' },
                { title: 'Group types', data: 'GroupTypes' }
            ], inventory.Groups);

            initDataTable('#tblAssignments', [
                { title: 'Policy / App', data: 'PolicyName' },
                { title: 'Type', data: 'PolicyType' },
                { title: 'Target type', data: 'TargetType' },
                { title: 'Target name', data: 'TargetName' }
            ], inventory.Assignments);

            initDataTable('#tblUnassigned', [
                { title: 'Name', data: 'DisplayName' },
                { title: 'Object type', data: 'ObjectType' },
                { title: 'Platform', data: 'Platform' },
                { title: 'Description', data: 'Description' }
            ], inventory.Unassigned);
        }

        function initGroupFilter() {
            const select = document.getElementById('groupFilter');
            const allAssignments = inventory.Assignments || [];
            const names = {};
            allAssignments.forEach(function (a) {
                if (a.TargetType === 'Group' && a.TargetName) {
                    names[a.TargetName] = true;
                }
            });

            Object.keys(names).sort().forEach(function (name) {
                const opt = document.createElement('option');
                opt.value = name;
                opt.textContent = name;
                select.appendChild(opt);
            });

            select.addEventListener('change', function () {
                const table = jQuery('#tblAssignments').DataTable();
                const value = select.value;
                if (!value) {
                    table.column(3).search('').draw();
                } else {
                    table.column(3).search('^' + value + '$', true, false).draw();
                }
            });
        }

        jQuery(function () {
            initMetrics();
            initCharts();
            initTables();
            initGroupFilter();
        });
    </script>
</body>
</html>
"@

    Set-Content -Path $OutputPath -Value $html -Encoding UTF8
    Write-Host "HTML dashboard written to $OutputPath" -ForegroundColor Green
}
