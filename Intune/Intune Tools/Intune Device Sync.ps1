<#
.SYNOPSIS
    Intune Console - Tabbed WPF GUI
.DESCRIPTION
    Left-side tabbed Intune console.

    Tabs:
      1) Sync Devices
      2) Assignments Lookup
      3) Apps Explorer
      4) Reports
      5) Settings (check + install missing modules)

.NOTES
    Requires Windows PowerShell 5.1+ on Windows for WPF.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

# -------------------------
# XAML UI
# -------------------------
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Intune Console"
        Height="690" Width="1220"
        ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen"
        Background="#FFF3F3F3">

    <Window.Resources>

        <Style TargetType="TabControl" x:Key="LeftTabs">
            <Setter Property="TabStripPlacement" Value="Left"/>
            <Setter Property="Background" Value="#001F4D"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="0"/>
        </Style>

        <Style TargetType="TabItem">
            <Setter Property="Foreground" Value="#D0D0D0"/>
            <Setter Property="Background" Value="#001F4D"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="12,10"/>
            <Setter Property="Margin" Value="0,2,0,2"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Background="{TemplateBinding Background}"
                                Padding="{TemplateBinding Padding}"
                                Margin="{TemplateBinding Margin}">
                            <ContentPresenter ContentSource="Header"
                                              RecognizesAccessKey="True" />
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter Property="Background" Value="#003B8E"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#002E73"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Foreground" Value="#808080"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="HeaderText" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#222222"/>
            <Setter Property="FontSize" Value="20"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
        </Style>
        <Style x:Key="LabelText" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#444"/>
            <Setter Property="FontSize" Value="12"/>
        </Style>
        <Style x:Key="DetailText" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#222222"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Margin" Value="0,2,0,2"/>
        </Style>

        <Style TargetType="Button">
            <Setter Property="Margin" Value="4"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="White"/>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Margin" Value="0"/>
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="#222222"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Margin" Value="4"/>
            <Setter Property="Padding" Value="4"/>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Margin" Value="4"/>
            <Setter Property="Padding" Value="4"/>
        </Style>

    </Window.Resources>

    <Grid>
        <TabControl Style="{StaticResource LeftTabs}" x:Name="MainTabs">

            <!-- ========================= -->
            <!-- Tab 1: Sync Devices       -->
            <!-- ========================= -->
            <TabItem Header="Sync Devices">
                <Grid Background="#FFF3F3F3" Margin="8">

                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Border Grid.Row="0"
                            Background="White"
                            CornerRadius="8"
                            Padding="12"
                            BorderBrush="#DDD"
                            BorderThickness="1"
                            Margin="0,0,0,8">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <TextBlock Text="Intune Device Sync Tool"
                                       Grid.Column="0"
                                       Style="{StaticResource HeaderText}"
                                       VerticalAlignment="Center"
                                       Margin="6,0,0,0"/>

                            <StackPanel Grid.Column="1"
                                        Orientation="Horizontal"
                                        VerticalAlignment="Top"
                                        HorizontalAlignment="Right">
                                <TextBlock x:Name="StatusText"
                                           Text="Not connected"
                                           Foreground="#444"
                                           Margin="0,0,6,0"/>
                                <Ellipse x:Name="ConnStatusDot"
                                         Width="14" Height="14"
                                         Fill="Red"
                                         VerticalAlignment="Center">
                                    <Ellipse.Effect>
                                        <DropShadowEffect Color="Red" BlurRadius="8" ShadowDepth="0"/>
                                    </Ellipse.Effect>
                                </Ellipse>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <Border Grid.Row="1" Background="White" CornerRadius="6" Padding="8"
                            Margin="0,0,0,8" BorderBrush="#DDD" BorderThickness="1">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="2*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <StackPanel Grid.Column="0">
                                <TextBlock Text="Tenant ID" Style="{StaticResource LabelText}"/>
                                <TextBox x:Name="TenantIdBox" Width="220"/>
                            </StackPanel>

                            <StackPanel Grid.Column="1">
                                <TextBlock Text="Client ID (App ID)" Style="{StaticResource LabelText}"/>
                                <TextBox x:Name="ClientIdBox" Width="220"/>
                            </StackPanel>

                            <StackPanel Grid.Column="2">
                                <TextBlock Text="Certificate Thumbprint" Style="{StaticResource LabelText}"/>
                                <TextBox x:Name="ThumbprintBox" Width="220"/>
                            </StackPanel>

                            <StackPanel Grid.Column="3" VerticalAlignment="Bottom">
                                <Button x:Name="ConnectButton" Content="Connect" Width="120"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <Grid Grid.Row="2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="4*"/>
                            <ColumnDefinition Width="3*"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0"
                                Background="White" CornerRadius="6" Padding="8"
                                BorderBrush="#DDD" BorderThickness="1"
                                Margin="0,0,6,0">

                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>

                                <Grid Grid.Row="0" Margin="0,0,0,2">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>

                                    <TextBlock Grid.Column="0"
                                               Text="Device name contains:"
                                               Style="{StaticResource LabelText}"
                                               VerticalAlignment="Center"
                                               Margin="0,0,6,0"/>

                                    <TextBox Grid.Column="1" x:Name="SearchBox" Width="250"/>

                                    <TextBlock Grid.Column="2"
                                               Text="OS:"
                                               Style="{StaticResource LabelText}"
                                               VerticalAlignment="Center"
                                               Margin="14,0,6,0"/>

                                    <ComboBox Grid.Column="3" x:Name="OsFilterBox" Width="190">
                                        <ComboBoxItem Content="All" IsSelected="True"/>
                                        <ComboBoxItem Content="Windows"/>
                                        <ComboBoxItem Content="iOS"/>
                                        <ComboBoxItem Content="Android"/>
                                        <ComboBoxItem Content="macOS"/>
                                    </ComboBox>
                                </Grid>

                                <WrapPanel Grid.Row="1" HorizontalAlignment="Left" Margin="0,0,0,6">
                                    <Button x:Name="SearchButton" Content="Search" Width="110"/>
                                    <Button x:Name="ListAllButton" Content="List all devices" Width="150"/>
                                </WrapPanel>

                                <DataGrid x:Name="DeviceGrid"
                                          Grid.Row="2"
                                          AutoGenerateColumns="False"
                                          IsReadOnly="True"
                                          SelectionMode="Extended"
                                          SelectionUnit="FullRow"
                                          AlternatingRowBackground="#FFF0F0F0">

                                    <DataGrid.Columns>
                                        <DataGridTextColumn Header="Device name" Binding="{Binding DeviceName}" Width="2*"/>
                                        <DataGridTextColumn Header="Device type" Binding="{Binding DeviceType}" Width="*"/>
                                        <DataGridTextColumn Header="Last sync" Binding="{Binding LastSyncDateTime}" Width="*" MinWidth="140"/>

                                        <DataGridTemplateColumn Header="Sync initiated" Width="Auto">
                                            <DataGridTemplateColumn.CellTemplate>
                                                <DataTemplate>
                                                    <TextBlock Text="●" FontSize="14" HorizontalAlignment="Center">
                                                        <TextBlock.Style>
                                                            <Style TargetType="TextBlock">
                                                                <Setter Property="Visibility" Value="Collapsed"/>
                                                                <Setter Property="Foreground" Value="Green"/>
                                                                <Style.Triggers>
                                                                    <DataTrigger Binding="{Binding SyncStatus}" Value="True">
                                                                        <Setter Property="Visibility" Value="Visible"/>
                                                                    </DataTrigger>
                                                                </Style.Triggers>
                                                            </Style>
                                                        </TextBlock.Style>
                                                    </TextBlock>
                                                </DataTemplate>
                                            </DataGridTemplateColumn.CellTemplate>
                                        </DataGridTemplateColumn>
                                    </DataGrid.Columns>
                                </DataGrid>
                            </Grid>
                        </Border>

                        <Border Grid.Column="1"
                                Background="White" CornerRadius="6"
                                Padding="14"
                                BorderBrush="#DDD" BorderThickness="1"
                                Margin="6,0,0,0">

                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                    <RowDefinition Height="Auto"/>
                                </Grid.RowDefinitions>

                                <TextBlock Grid.Row="0"
                                           Text="Device details"
                                           Foreground="#111"
                                           FontWeight="SemiBold"
                                           FontSize="14"
                                           Margin="0,0,0,8"/>

                                <StackPanel Grid.Row="1">
                                    <TextBlock x:Name="DetailDevice" Style="{StaticResource DetailText}"/>
                                    <TextBlock x:Name="DetailUser" Style="{StaticResource DetailText}"/>
                                    <TextBlock x:Name="DetailOs" Style="{StaticResource DetailText}"/>
                                    <TextBlock x:Name="DetailCompliance" Style="{StaticResource DetailText}"/>
                                    <TextBlock x:Name="DetailLastSync" Style="{StaticResource DetailText}"/>
                                </StackPanel>

                                <StackPanel Grid.Row="2" Margin="0,10,0,0">
                                    <Separator Margin="0,0,0,8"/>
                                    <WrapPanel>
                                        <Button x:Name="SyncSelectedButton" Content="Sync selected" Width="120"/>
                                        <Button x:Name="SyncAllButton" Content="Sync all listed" Width="130"/>
                                        <Button x:Name="ExportButton" Content="Export to CSV" Width="120"/>
                                    </WrapPanel>
                                </StackPanel>
                            </Grid>
                        </Border>
                    </Grid>

                    <TextBlock x:Name="OperationStatusText"
                               Grid.Row="3"
                               Margin="0,8,0,0"
                               Foreground="#444"
                               FontSize="12"/>
                </Grid>
            </TabItem>

            <!-- ========================= -->
            <!-- Tab 2: Assignments        -->
            <!-- ========================= -->
            <TabItem Header="Assignments">
                <Grid Background="#FFF3F3F3" Margin="8">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Border Grid.Row="0" Background="White" CornerRadius="8" Padding="12"
                            BorderBrush="#DDD" BorderThickness="1" Margin="0,0,0,8">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <TextBlock Text="Intune Assignment Lookup"
                                       Style="{StaticResource HeaderText}"
                                       Margin="6,0,0,0"
                                       VerticalAlignment="Center"/>

                            <TextBlock Grid.Column="1" Text="Enter group name or ObjectId"
                                       Foreground="#555" VerticalAlignment="Center"/>
                        </Grid>
                    </Border>

                    <Border Grid.Row="1" Background="White" CornerRadius="6" Padding="10"
                            BorderBrush="#DDD" BorderThickness="1">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <Grid Grid.Row="0" Margin="0,0,0,8">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>

                                <TextBlock Grid.Column="0"
                                           Text="Group:"
                                           Style="{StaticResource LabelText}"
                                           VerticalAlignment="Center"
                                           Margin="0,0,6,0"/>

                                <TextBox Grid.Column="1" x:Name="GroupSearchBox" MinWidth="420"/>

                                <Button Grid.Column="2" x:Name="FindAssignmentsButton"
                                        Content="Find assignments" Width="140" Margin="8,0,0,0"/>

                                <Button Grid.Column="3" x:Name="ExportAssignmentsButton"
                                        Content="Export CSV" Width="110" Margin="6,0,0,0"/>
                            </Grid>

                            <DataGrid x:Name="AssignmentsGrid"
                                      Grid.Row="1"
                                      AutoGenerateColumns="False"
                                      IsReadOnly="True"
                                      AlternatingRowBackground="#FFF0F0F0">
                                <DataGrid.Columns>
                                    <DataGridTextColumn Header="Type" Binding="{Binding Type}" Width="1.2*"/>
                                    <DataGridTextColumn Header="Item name" Binding="{Binding Name}" Width="2*"/>
                                    <DataGridTextColumn Header="Assignment" Binding="{Binding Assignment}" Width="*"/>
                                    <DataGridTextColumn Header="Item Id" Binding="{Binding Id}" Width="2*" MinWidth="220"/>
                                </DataGrid.Columns>
                            </DataGrid>
                        </Grid>
                    </Border>

                    <TextBlock x:Name="AssignmentsStatusText"
                               Grid.Row="2"
                               Margin="0,8,0,0"
                               Foreground="#444"
                               FontSize="12"/>
                </Grid>
            </TabItem>

            <!-- ========================= -->
            <!-- Tab 3: Apps               -->
            <!-- ========================= -->
            <TabItem Header="Apps">
                <Grid Background="#FFF3F3F3" Margin="8">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Border Grid.Row="0" Background="White" CornerRadius="8" Padding="12"
                            BorderBrush="#DDD" BorderThickness="1" Margin="0,0,0,8">
                        <TextBlock Text="Intune Apps Explorer"
                                   Style="{StaticResource HeaderText}"
                                   Margin="6,0,0,0"/>
                    </Border>

                    <Grid Grid.Row="1">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="4*"/>
                            <ColumnDefinition Width="3*"/>
                        </Grid.ColumnDefinitions>

                        <Border Grid.Column="0" Background="White" CornerRadius="6" Padding="8"
                                BorderBrush="#DDD" BorderThickness="1" Margin="0,0,6,0">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>

                                <WrapPanel Grid.Row="0">
                                    <TextBlock Text="App name contains:" Style="{StaticResource LabelText}" VerticalAlignment="Center" Margin="0,0,6,0"/>
                                    <TextBox x:Name="AppSearchBox" Width="260"/>
                                    <TextBlock Text="Platform:" Style="{StaticResource LabelText}" VerticalAlignment="Center" Margin="10,0,6,0"/>
                                    <ComboBox x:Name="AppPlatformBox" Width="160">
                                        <ComboBoxItem Content="All" IsSelected="True"/>
                                        <ComboBoxItem Content="Windows"/>
                                        <ComboBoxItem Content="iOS"/>
                                        <ComboBoxItem Content="Android"/>
                                        <ComboBoxItem Content="macOS"/>
                                    </ComboBox>
                                    <Button x:Name="SearchAppsButton" Content="Search apps" Width="110"/>
                                    <Button x:Name="ListAllAppsButton" Content="List all apps" Width="110"/>
                                    <Button x:Name="ExportAppsButton" Content="Export CSV" Width="110"/>
                                </WrapPanel>

                                <DataGrid x:Name="AppsGrid"
                                          Grid.Row="1"
                                          AutoGenerateColumns="False"
                                          IsReadOnly="True"
                                          SelectionMode="Single"
                                          AlternatingRowBackground="#FFF0F0F0"
                                          Margin="0,6,0,0">
                                    <DataGrid.Columns>
                                        <DataGridTextColumn Header="App name" Binding="{Binding DisplayName}" Width="2*"/>
                                        <DataGridTextColumn Header="App type" Binding="{Binding AppType}" Width="*"/>
                                        <DataGridTextColumn Header="Assigned" Binding="{Binding IsAssigned}" Width="*"/>
                                        <DataGridTextColumn Header="App Id" Binding="{Binding Id}" Width="2*" MinWidth="220"/>
                                    </DataGrid.Columns>
                                </DataGrid>
                            </Grid>
                        </Border>

                        <Border Grid.Column="1" Background="White" CornerRadius="6" Padding="12"
                                BorderBrush="#DDD" BorderThickness="1" Margin="6,0,0,0">
                            <StackPanel>
                                <TextBlock Text="App details" FontWeight="SemiBold" FontSize="14" Margin="0,0,0,8"/>
                                <TextBlock x:Name="AppDetailName" Style="{StaticResource DetailText}"/>
                                <TextBlock x:Name="AppDetailPublisher" Style="{StaticResource DetailText}"/>
                                <TextBlock x:Name="AppDetailType" Style="{StaticResource DetailText}"/>
                                <TextBlock x:Name="AppDetailPlatforms" Style="{StaticResource DetailText}"/>
                                <TextBlock x:Name="AppDetailAssignedCount" Style="{StaticResource DetailText}"/>
                                <TextBlock x:Name="AppDetailLastModified" Style="{StaticResource DetailText}"/>
                            </StackPanel>
                        </Border>
                    </Grid>

                    <TextBlock x:Name="AppsStatusText"
                               Grid.Row="2"
                               Margin="0,8,0,0"
                               Foreground="#444"
                               FontSize="12"/>
                </Grid>
            </TabItem>

            <!-- ========================= -->
            <!-- Tab 4: Reports            -->
            <!-- ========================= -->
            <TabItem Header="Reports">
                <Grid Background="#FFF3F3F3" Margin="8">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <Border Grid.Row="0" Background="White" CornerRadius="8" Padding="12"
                            BorderBrush="#DDD" BorderThickness="1" Margin="0,0,0,8">
                        <TextBlock Text="Intune Reports"
                                   Style="{StaticResource HeaderText}"
                                   Margin="6,0,0,0"/>
                    </Border>

                    <Border Grid.Row="1" Background="White" CornerRadius="6" Padding="10"
                            BorderBrush="#DDD" BorderThickness="1">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>

                            <WrapPanel Grid.Row="0">
                                <TextBlock Text="Report type:" Style="{StaticResource LabelText}" VerticalAlignment="Center" Margin="0,0,6,0"/>
                                <ComboBox x:Name="ReportTypeBox" Width="240">
                                    <ComboBoxItem Content="Device compliance report" IsSelected="True"/>
                                    <ComboBoxItem Content="Assigned apps report"/>
                                </ComboBox>
                                <Button x:Name="RunReportButton" Content="Run report" Width="110"/>
                                <Button x:Name="ExportReportButton" Content="Export CSV" Width="110"/>
                            </WrapPanel>

                            <DataGrid x:Name="ReportsGrid"
                                      Grid.Row="1"
                                      AutoGenerateColumns="True"
                                      IsReadOnly="True"
                                      AlternatingRowBackground="#FFF0F0F0"
                                      Margin="0,6,0,0"/>
                        </Grid>
                    </Border>

                    <TextBlock x:Name="ReportsStatusText"
                               Grid.Row="2"
                               Margin="0,8,0,0"
                               Foreground="#444"
                               FontSize="12"/>
                </Grid>
            </TabItem>

            <!-- ========================= -->
            <!-- Tab 5: Settings           -->
            <!-- ========================= -->
            <TabItem Header="Settings">
                <Grid Background="#FFF3F3F3" Margin="8">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <Border Grid.Row="0" Background="White" CornerRadius="8" Padding="12"
                            BorderBrush="#DDD" BorderThickness="1" Margin="0,0,0,8">
                        <TextBlock Text="Console Settings"
                                   Style="{StaticResource HeaderText}"
                                   Margin="6,0,0,0"/>
                    </Border>

                    <Border Grid.Row="1" Background="White" CornerRadius="6" Padding="12"
                            BorderBrush="#DDD" BorderThickness="1">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>

                            <StackPanel Grid.Row="0">
                                <TextBlock Text="Current Graph context:" FontWeight="SemiBold" Margin="0,0,0,4"/>
                                <TextBlock x:Name="SettingsTenantText" Style="{StaticResource DetailText}"/>
                                <TextBlock x:Name="SettingsAccountText" Style="{StaticResource DetailText}"/>
                            </StackPanel>

                            <WrapPanel Grid.Row="1" Margin="0,8,0,8">
                                <Button x:Name="CheckModulesButton" Content="Check modules" Width="140"/>
                                <Button x:Name="InstallModulesButton" Content="Install missing modules" Width="180"/>
                                <Button x:Name="DisconnectButton" Content="Disconnect Graph" Width="140"/>
                                <Button x:Name="ResetWorkspaceButton" Content="Reset workspace" Width="140"/>
                            </WrapPanel>

                            <!-- Auto columns from DataTable:
                                 Module | InstallState | Status | Version -->
                            <DataGrid x:Name="ModulesGrid"
                                      Grid.Row="2"
                                      AutoGenerateColumns="True"
                                      IsReadOnly="True"
                                      AlternatingRowBackground="#FFF0F0F0"/>

                            <TextBlock x:Name="SettingsStatusText"
                                       Grid.Row="3"
                                       Margin="0,8,0,0"
                                       Foreground="#444"
                                       FontSize="12"/>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

        </TabControl>
    </Grid>
</Window>
'@

$reader = [System.Xml.XmlNodeReader]::new([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# -------------------------
# Controls
# -------------------------
# Sync tab
$StatusText          = $window.FindName("StatusText")
$ConnStatusDot       = $window.FindName("ConnStatusDot")
$TenantIdBox         = $window.FindName("TenantIdBox")
$ClientIdBox         = $window.FindName("ClientIdBox")
$ThumbprintBox       = $window.FindName("ThumbprintBox")
$ConnectButton       = $window.FindName("ConnectButton")

$SearchBox           = $window.FindName("SearchBox")
$OsFilterBox         = $window.FindName("OsFilterBox")
$SearchButton        = $window.FindName("SearchButton")
$ListAllButton       = $window.FindName("ListAllButton")
$DeviceGrid          = $window.FindName("DeviceGrid")

$SyncSelectedButton  = $window.FindName("SyncSelectedButton")
$SyncAllButton       = $window.FindName("SyncAllButton")
$ExportButton        = $window.FindName("ExportButton")

$OperationStatusText = $window.FindName("OperationStatusText")

$DetailDevice        = $window.FindName("DetailDevice")
$DetailUser          = $window.FindName("DetailUser")
$DetailOs            = $window.FindName("DetailOs")
$DetailCompliance    = $window.FindName("DetailCompliance")
$DetailLastSync      = $window.FindName("DetailLastSync")

# Assignments tab
$GroupSearchBox           = $window.FindName("GroupSearchBox")
$FindAssignmentsButton    = $window.FindName("FindAssignmentsButton")
$ExportAssignmentsButton  = $window.FindName("ExportAssignmentsButton")
$AssignmentsGrid          = $window.FindName("AssignmentsGrid")
$AssignmentsStatusText    = $window.FindName("AssignmentsStatusText")

# Apps tab
$AppSearchBox         = $window.FindName("AppSearchBox")
$AppPlatformBox       = $window.FindName("AppPlatformBox")
$SearchAppsButton     = $window.FindName("SearchAppsButton")
$ListAllAppsButton    = $window.FindName("ListAllAppsButton")
$ExportAppsButton     = $window.FindName("ExportAppsButton")
$AppsGrid             = $window.FindName("AppsGrid")
$AppsStatusText       = $window.FindName("AppsStatusText")

$AppDetailName          = $window.FindName("AppDetailName")
$AppDetailPublisher     = $window.FindName("AppDetailPublisher")
$AppDetailType          = $window.FindName("AppDetailType")
$AppDetailPlatforms     = $window.FindName("AppDetailPlatforms")
$AppDetailAssignedCount = $window.FindName("AppDetailAssignedCount")
$AppDetailLastModified  = $window.FindName("AppDetailLastModified")

# Reports tab
$ReportTypeBox       = $window.FindName("ReportTypeBox")
$RunReportButton     = $window.FindName("RunReportButton")
$ExportReportButton  = $window.FindName("ExportReportButton")
$ReportsGrid         = $window.FindName("ReportsGrid")
$ReportsStatusText   = $window.FindName("ReportsStatusText")

# Settings tab
$CheckModulesButton     = $window.FindName("CheckModulesButton")
$InstallModulesButton   = $window.FindName("InstallModulesButton")
$DisconnectButton       = $window.FindName("DisconnectButton")
$ResetWorkspaceButton   = $window.FindName("ResetWorkspaceButton")
$ModulesGrid            = $window.FindName("ModulesGrid")
$SettingsTenantText     = $window.FindName("SettingsTenantText")
$SettingsAccountText    = $window.FindName("SettingsAccountText")
$SettingsStatusText     = $window.FindName("SettingsStatusText")

# -------------------------
# State
# -------------------------
$script:IsConnected = $false
$script:GraphModulesLoaded = $false
$script:DeviceTable = $null
$script:AssignmentsTable = $null
$script:AppsTable = $null
$script:ReportsTable = $null
$script:ModulesTable = $null

# FIXED REQUIRED MODULES LIST
# (Removed the non-existent Microsoft.Graph.DeviceManagement.Configuration)
$script:RequiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.DeviceManagement",
    "Microsoft.Graph.DeviceManagement.Actions",
    "Microsoft.Graph.DeviceManagement.Apps",
    "Microsoft.Graph.Groups"
)

# -------------------------
# Helpers
# -------------------------
function Show-Info($Title,$Message){
    [System.Windows.MessageBox]::Show($Message, $Title, 'OK', 'Information') | Out-Null
}
function Show-Error($Title,$Message){
    [System.Windows.MessageBox]::Show($Message, $Title, 'OK', 'Error') | Out-Null
}

function Ensure-PowerShellGallery {
    # PS 5.1 often needs TLS 1.2 to talk to PSGallery
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    } catch {}

    # Ensure PSGallery registered and trusted
    try {
        $repo = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
        if (-not $repo) {
            Register-PSRepository -Default -ErrorAction Stop
        }
        if ((Get-PSRepository -Name "PSGallery").InstallationPolicy -ne "Trusted") {
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted | Out-Null
        }
    } catch {}
}

function Import-GraphModules {
    if ($script:GraphModulesLoaded) { return }

    foreach ($m in $script:RequiredModules) {
        $mod = Get-Module -ListAvailable -Name $m | Select-Object -First 1
        if (-not $mod) {
            throw "Required module '$m' not found. Install it from Settings tab."
        }
        Import-Module $m -ErrorAction Stop | Out-Null
    }

    $script:GraphModulesLoaded = $true
}

function Set-ConnectionIndicator([bool]$Connected){
    if ($Connected) {
        $ConnStatusDot.Fill = [System.Windows.Media.Brushes]::LimeGreen
        if ($ConnStatusDot.Effect) { $ConnStatusDot.Effect.Color = [System.Windows.Media.Colors]::LimeGreen }
        $StatusText.Text = "Connected"
    } else {
        $ConnStatusDot.Fill = [System.Windows.Media.Brushes]::Red
        if ($ConnStatusDot.Effect) { $ConnStatusDot.Effect.Color = [System.Windows.Media.Colors]::Red }
        $StatusText.Text = "Not connected"
    }
}

function Update-SettingsContext {
    try {
        $ctx = Get-MgContext
        if ($ctx) {
            $SettingsTenantText.Text  = "Tenant: $($ctx.TenantId)"
            $SettingsAccountText.Text = "Account: $($ctx.Account)"
        } else {
            $SettingsTenantText.Text  = "Tenant: -"
            $SettingsAccountText.Text = "Account: -"
        }
    } catch {
        $SettingsTenantText.Text  = "Tenant: -"
        $SettingsAccountText.Text = "Account: -"
    }
}

function Get-MissingModules {
    $missing = @()
    foreach ($m in $script:RequiredModules) {
        $installed = Get-Module -ListAvailable -Name $m | Select-Object -First 1
        if (-not $installed) { $missing += $m }
    }
    return $missing
}

function Get-ModulesRow {
    param([string]$ModuleName)
    if (-not $script:ModulesTable) { return $null }
    return $script:ModulesTable.Rows | Where-Object { $_.Module -eq $ModuleName } | Select-Object -First 1
}

function Check-Modules {
    $dt = New-Object System.Data.DataTable
    $dt.Columns.Add("Module",[string]) | Out-Null
    $dt.Columns.Add("InstallState",[string]) | Out-Null   # NEW COLUMN
    $dt.Columns.Add("Status",[string]) | Out-Null
    $dt.Columns.Add("Version",[string]) | Out-Null

    foreach ($m in $script:RequiredModules) {
        $r = $dt.NewRow()
        $r["Module"] = $m

        $installed = Get-Module -ListAvailable -Name $m | Sort-Object Version -Descending | Select-Object -First 1
        if ($installed) {
            $r["InstallState"] = "Installed"
            $r["Status"] = "Installed"
            $r["Version"] = $installed.Version.ToString()
        } else {
            $r["InstallState"] = "Not installed"
            $r["Status"] = "Missing"
            $r["Version"] = "-"
        }

        $dt.Rows.Add($r)
    }

    $script:ModulesTable = $dt
    $ModulesGrid.ItemsSource = $dt.DefaultView

    $missing = Get-MissingModules
    if ($missing.Count -gt 0) {
        $SettingsStatusText.Text = "Missing modules: $($missing -join ', ')"
    } else {
        $SettingsStatusText.Text = "All required modules are installed."
    }
}

function Install-MissingModules {
    $missing = Get-MissingModules
    if ($missing.Count -eq 0) {
        $SettingsStatusText.Text = "No missing modules to install."
        return
    }

    $msg = "This will install the following modules for the current user:`n`n$($missing -join "`n")`n`nContinue?"
    $confirm = [System.Windows.MessageBox]::Show($msg, "Install missing modules", "YesNo", "Warning")
    if ($confirm -ne "Yes") { return }

    Ensure-PowerShellGallery

    try {
        foreach ($m in $missing) {

            # Update UI to Installing...
            $row = Get-ModulesRow -ModuleName $m
            if ($row) {
                $row["InstallState"] = "Installing..."
                $row["Status"] = "Missing"
                $ModulesGrid.Items.Refresh()
            }

            $SettingsStatusText.Text = "Installing $m ..."
            Install-Module -Name $m -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop

            Import-Module $m -ErrorAction SilentlyContinue | Out-Null

            # Update UI to Installed
            $installed = Get-Module -ListAvailable -Name $m | Sort-Object Version -Descending | Select-Object -First 1
            if ($row) {
                $row["InstallState"] = "Installed"
                $row["Status"] = "Installed"
                $row["Version"] = if ($installed) { $installed.Version.ToString() } else { "-" }
                $ModulesGrid.Items.Refresh()
            }
        }

        $SettingsStatusText.Text = "Module installation complete."
        $script:GraphModulesLoaded = $false
        Check-Modules
        Show-Info "Modules installed" "Missing modules have been installed for the current user."
    }
    catch {
        $SettingsStatusText.Text = "Module installation failed."
        Show-Error "Install error" $_.Exception.Message
        Check-Modules
    }
}

# -------------------------
# Sync Devices logic
# -------------------------
function Get-Devices([string]$Name,[string]$OS){
    if (-not $script:IsConnected) { return @() }

    $filterParts = @()
    if ($Name) {
        $safeName = $Name.Replace("'", "''")
        $filterParts += "contains(deviceName,'$safeName')"
    }
    if ($OS -and $OS -ne "All") {
        $filterParts += "contains(operatingSystem,'$OS')"
    }
    $filter = if ($filterParts.Count) { $filterParts -join " and " } else { $null }

    $params = @{ All = $true }
    if ($filter) { $params.Filter = $filter }

    Get-MgDeviceManagementManagedDevice @params | Sort-Object DeviceName
}

function Load-DevicesGrid($Devices){
    $dt = New-Object System.Data.DataTable
    $dt.Columns.Add("DeviceName",[string]) | Out-Null
    $dt.Columns.Add("DeviceType",[string]) | Out-Null
    $dt.Columns.Add("LastSyncDateTime",[string]) | Out-Null
    $dt.Columns.Add("SyncStatus",[bool]) | Out-Null

    foreach ($d in $Devices) {
        $r = $dt.NewRow()
        $r["DeviceName"] = $d.DeviceName
        $r["DeviceType"] = $d.OperatingSystem
        $r["LastSyncDateTime"] = $d.LastSyncDateTime
        $r["SyncStatus"] = $false
        $dt.Rows.Add($r)
    }

    $script:DeviceTable = $dt
    $DeviceGrid.ItemsSource = $dt.DefaultView

    if ($dt.Rows.Count -eq 0) {
        $OperationStatusText.Text = "No devices found for the specified search criteria."
        $DetailDevice.Text = "Device:"
        $DetailUser.Text = "User:"
        $DetailOs.Text = "OS:"
        $DetailCompliance.Text = "Compliance:"
        $DetailLastSync.Text = "Last sync:"
    } else {
        $OperationStatusText.Text = "Loaded $($dt.Rows.Count) devices."
    }
}

function Update-DeviceDetails($RowView){
    if (-not $RowView) { return }
    $row = $RowView.Row
    $DetailDevice.Text = "Device: $($row["DeviceName"])"
    $DetailUser.Text   = "User: (not loaded in grid view)"
    $DetailOs.Text     = "OS: $($row["DeviceType"])"
    $DetailCompliance.Text = "Compliance: (not loaded in grid view)"
    $DetailLastSync.Text   = "Last sync: $($row["LastSyncDateTime"])"
}

# -------------------------
# Assignments / Apps / Reports logic
# (same as your last working version)
# -------------------------
function Resolve-GroupId([string]$GroupInput){
    if ([string]::IsNullOrWhiteSpace($GroupInput)) { return $null }

    if ($GroupInput -match '^[0-9a-fA-F-]{36}$') {
        try { return (Get-MgGroup -GroupId $GroupInput).Id } catch { return $null }
    }

    $safe = $GroupInput.Replace("'","''")
    $g = Get-MgGroup -Filter "displayName eq '$safe'" -ConsistencyLevel eventual -Top 1
    if ($g) { return $g[0].Id }

    $g2 = Get-MgGroup -Filter "startswith(displayName,'$safe')" -ConsistencyLevel eventual -Top 1
    if ($g2) { return $g2[0].Id }

    return $null
}

function New-AssignmentsTable {
    $dt = New-Object System.Data.DataTable
    $dt.Columns.Add("Type",[string]) | Out-Null
    $dt.Columns.Add("Name",[string]) | Out-Null
    $dt.Columns.Add("Assignment",[string]) | Out-Null
    $dt.Columns.Add("Id",[string]) | Out-Null
    $dt
}

function Add-AssignmentHit($Table,$Type,$Name,$Assignment,$Id){
    $r = $Table.NewRow()
    $r["Type"] = $Type
    $r["Name"] = $Name
    $r["Assignment"] = $Assignment
    $r["Id"] = $Id
    $Table.Rows.Add($r)
}

function Find-IntuneAssignmentsForGroup([string]$GroupId){
    $dt = New-AssignmentsTable

    $configs = Get-MgDeviceManagementDeviceConfiguration -All -ExpandProperty assignments
    foreach ($c in $configs) {
        foreach ($a in ($c.Assignments | ForEach-Object { $_ })) {
            if ($a.Target.GroupId -eq $GroupId) {
                $assignType = if ($a.Target.AdditionalProperties.'@odata.type' -like '*exclusion*') { "Exclude" } else { "Include" }
                Add-AssignmentHit $dt "Config profile" $c.DisplayName $assignType $c.Id
            }
        }
    }

    $sc = Get-MgDeviceManagementConfigurationPolicy -All -ExpandProperty assignments
    foreach ($p in $sc) {
        foreach ($a in ($p.Assignments | ForEach-Object { $_ })) {
            if ($a.Target.GroupId -eq $GroupId) {
                $assignType = if ($a.Target.AdditionalProperties.'@odata.type' -like '*exclusion*') { "Exclude" } else { "Include" }
                Add-AssignmentHit $dt "Settings catalog" $p.Name $assignType $p.Id
            }
        }
    }

    $comp = Get-MgDeviceManagementDeviceCompliancePolicy -All -ExpandProperty assignments
    foreach ($cp in $comp) {
        foreach ($a in ($cp.Assignments | ForEach-Object { $_ })) {
            if ($a.Target.GroupId -eq $GroupId) {
                $assignType = if ($a.Target.AdditionalProperties.'@odata.type' -like '*exclusion*') { "Exclude" } else { "Include" }
                Add-AssignmentHit $dt "Compliance policy" $cp.DisplayName $assignType $cp.Id
            }
        }
    }

    $apps = Get-MgDeviceAppManagementMobileApp -All -Filter "isAssigned eq true" -ExpandProperty assignments
    foreach ($app in $apps) {
        foreach ($a in ($app.Assignments | ForEach-Object { $_ })) {
            if ($a.Target.GroupId -eq $GroupId) {
                $assignType = if ($a.Target.AdditionalProperties.'@odata.type' -like '*exclusion*') { "Exclude" } else { "Include" }
                Add-AssignmentHit $dt "App" $app.DisplayName $assignType $app.Id
            }
        }
    }

    $dt
}

function Get-AppTypeLabel($app){
    $odata = $app.AdditionalProperties.'@odata.type'
    if (-not $odata) { return "Unknown" }
    ($odata -replace '#microsoft.graph.','')
}

function Guess-Platform($app){
    $t = (Get-AppTypeLabel $app).ToLowerInvariant()
    if ($t -match 'win32|windows|msix|office|webapp') { return "Windows" }
    if ($t -match 'ios') { return "iOS" }
    if ($t -match 'android') { return "Android" }
    if ($t -match 'mac|osx') { return "macOS" }
    "Other"
}

function Load-AppsGrid($Apps){
    $dt = New-Object System.Data.DataTable
    $dt.Columns.Add("DisplayName",[string]) | Out-Null
    $dt.Columns.Add("AppType",[string]) | Out-Null
    $dt.Columns.Add("IsAssigned",[string]) | Out-Null
    $dt.Columns.Add("Id",[string]) | Out-Null
    $dt.Columns.Add("_appObj",[object]) | Out-Null

    foreach ($a in $Apps) {
        $r = $dt.NewRow()
        $r["DisplayName"] = $a.DisplayName
        $r["AppType"] = Get-AppTypeLabel $a
        $r["IsAssigned"] = [string]$a.IsAssigned
        $r["Id"] = $a.Id
        $r["_appObj"] = $a
        $dt.Rows.Add($r)
    }

    $script:AppsTable = $dt
    $AppsGrid.ItemsSource = $dt.DefaultView
    $AppsStatusText.Text = "Loaded $($dt.Rows.Count) app(s)."
}

function Update-AppDetails($RowView){
    if (-not $RowView) { return }
    $app = $RowView.Row["_appObj"]
    if (-not $app) { return }

    $AppDetailName.Text = "Name: $($app.DisplayName)"
    $AppDetailPublisher.Text = "Publisher: $($app.Publisher)"
    $atype = Get-AppTypeLabel $app
    $AppDetailType.Text = "Type: $atype"
    $AppDetailPlatforms.Text = "Platform (heuristic): $(Guess-Platform $app)"
    $AppDetailAssignedCount.Text = "Assignments count: $([int]($app.Assignments.Count))"
    $AppDetailLastModified.Text = "Last modified: $($app.LastModifiedDateTime)"
}

function Search-Apps([string]$Name,[string]$Platform){
    if (-not $script:IsConnected) { return @() }

    $params = @{ All = $true }
    if ($Name) {
        $safe = $Name.Replace("'","''")
        $params.Filter = "contains(displayName,'$safe')"
    }

    $apps = Get-MgDeviceAppManagementMobileApp @params
    if ($Platform -and $Platform -ne "All") {
        $apps = $apps | Where-Object { (Guess-Platform $_) -eq $Platform }
    }
    $apps | Sort-Object DisplayName
}

function Run-DeviceComplianceReport {
    $devs = Get-MgDeviceManagementManagedDevice -All
    $dt = New-Object System.Data.DataTable
    "DeviceName","OperatingSystem","ComplianceState","UserPrincipalName","LastSyncDateTime","Id" |
        ForEach-Object { $dt.Columns.Add($_,[string]) | Out-Null }

    foreach ($d in $devs) {
        $r = $dt.NewRow()
        $r["DeviceName"] = $d.DeviceName
        $r["OperatingSystem"] = $d.OperatingSystem
        $r["ComplianceState"] = $d.ComplianceState
        $r["UserPrincipalName"] = $d.UserPrincipalName
        $r["LastSyncDateTime"] = $d.LastSyncDateTime
        $r["Id"] = $d.Id
        $dt.Rows.Add($r)
    }
    $dt
}

function Run-AssignedAppsReport {
    $apps = Get-MgDeviceAppManagementMobileApp -All -Filter "isAssigned eq true"
    $dt = New-Object System.Data.DataTable
    "DisplayName","AppType","Publisher","LastModifiedDateTime","Id" |
        ForEach-Object { $dt.Columns.Add($_,[string]) | Out-Null }

    foreach ($a in $apps) {
        $r = $dt.NewRow()
        $r["DisplayName"] = $a.DisplayName
        $r["AppType"] = Get-AppTypeLabel $a
        $r["Publisher"] = $a.Publisher
        $r["LastModifiedDateTime"] = $a.LastModifiedDateTime
        $r["Id"] = $a.Id
        $dt.Rows.Add($r)
    }
    $dt
}

# -------------------------
# Events
# -------------------------
$ConnectButton.Add_Click({
    try {
        $missing = Get-MissingModules
        if ($missing.Count -gt 0) {
            Show-Info "Missing modules" "Install missing modules from Settings tab first."
            return
        }

        Import-GraphModules

        Connect-MgGraph -Scopes `
            "DeviceManagementManagedDevices.Read.All", `
            "DeviceManagementManagedDevices.ReadWrite.All", `
            "DeviceManagementConfiguration.Read.All", `
            "DeviceManagementApps.Read.All", `
            "Group.Read.All" `
            -NoWelcome -ErrorAction Stop

        $script:IsConnected = $true
        Set-ConnectionIndicator $true
        $OperationStatusText.Text = "Connected to Microsoft Graph."
        $AssignmentsStatusText.Text = "Connected. Ready to search assignments."
        $AppsStatusText.Text = "Connected. Ready to search apps."
        $ReportsStatusText.Text = "Connected. Ready to run reports."
        Update-SettingsContext
    }
    catch {
        $script:IsConnected = $false
        Set-ConnectionIndicator $false
        $OperationStatusText.Text = "Connection failed."
        Show-Error "Connection error" $_.Exception.Message
        Update-SettingsContext
    }
})

$SearchButton.Add_Click({
    try {
        if (-not $script:IsConnected) { Show-Info "Not connected" "Connect to Graph first." ; return }
        $devices = Get-Devices $SearchBox.Text.Trim() ($OsFilterBox.SelectedItem).Content
        Load-DevicesGrid $devices
    }
    catch { Show-Error "Search error" $_.Exception.Message }
})

$ListAllButton.Add_Click({
    try {
        if (-not $script:IsConnected) { Show-Info "Not connected" "Connect to Graph first." ; return }
        $devices = Get-Devices "" ($OsFilterBox.SelectedItem).Content
        Load-DevicesGrid $devices
    }
    catch { Show-Error "List error" $_.Exception.Message }
})

$DeviceGrid.Add_SelectionChanged({
    if ($DeviceGrid.SelectedItem) {
        Update-DeviceDetails ($DeviceGrid.SelectedItem -as [System.Data.DataRowView])
    }
})

$SyncSelectedButton.Add_Click({
    if (-not $script:DeviceTable) { Show-Info "Sync" "No devices loaded."; return }
    if ($DeviceGrid.SelectedItems.Count -eq 0) { Show-Info "Sync" "Select at least one device."; return }
    foreach ($i in $DeviceGrid.SelectedItems) { $i.Row["SyncStatus"] = $true }
    $OperationStatusText.Text = "Sync initiated for selected devices."
})

$SyncAllButton.Add_Click({
    if (-not $script:DeviceTable -or $script:DeviceTable.Rows.Count -eq 0) { Show-Info "Sync" "No devices loaded."; return }
    $result = [System.Windows.MessageBox]::Show(
        "This will initiate sync for all listed devices. Continue?",
        "Confirm bulk sync",
        "YesNo",
        "Warning"
    )
    if ($result -ne "Yes") { return }
    foreach ($r in $script:DeviceTable.Rows) { $r["SyncStatus"] = $true }
    $OperationStatusText.Text = "Sync initiated for all listed devices."
})

$ExportButton.Add_Click({
    if (-not $script:DeviceTable -or $script:DeviceTable.Rows.Count -eq 0) { $OperationStatusText.Text = "Nothing to export."; return }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "CSV files (*.csv)|*.csv"
    $dlg.FileName = "IntuneDevices.csv"
    if ($dlg.ShowDialog()) {
        $script:DeviceTable | Export-Csv $dlg.FileName -NoTypeInformation -Encoding UTF8
        Show-Info "Export complete" "Exported to:`n$($dlg.FileName)"
    }
})

# Assignments events
$FindAssignmentsButton.Add_Click({
    try {
        if (-not $script:IsConnected) { Show-Info "Not connected" "Connect to Graph first."; return }
        $AssignmentsStatusText.Text = "Resolving group..."
        $gid = Resolve-GroupId $GroupSearchBox.Text.Trim()
        if (-not $gid) {
            $AssignmentsStatusText.Text = "Group not found. Check the name or ObjectId."
            $AssignmentsGrid.ItemsSource = $null
            $script:AssignmentsTable = $null
            return
        }
        $AssignmentsStatusText.Text = "Searching assignments..."
        $dt = Find-IntuneAssignmentsForGroup $gid
        $script:AssignmentsTable = $dt
        $AssignmentsGrid.ItemsSource = $dt.DefaultView
        $AssignmentsStatusText.Text = if ($dt.Rows.Count) { "Found $($dt.Rows.Count) assignment(s)." } else { "No assignments found." }
    }
    catch {
        $AssignmentsStatusText.Text = "Lookup failed."
        Show-Error "Assignments error" $_.Exception.Message
    }
})

$ExportAssignmentsButton.Add_Click({
    if (-not $script:AssignmentsTable -or $script:AssignmentsTable.Rows.Count -eq 0) { $AssignmentsStatusText.Text = "Nothing to export."; return }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "CSV files (*.csv)|*.csv"
    $dlg.FileName = "IntuneAssignments.csv"
    if ($dlg.ShowDialog()) {
        $script:AssignmentsTable | Export-Csv $dlg.FileName -NoTypeInformation -Encoding UTF8
        Show-Info "Export complete" "Exported to:`n$($dlg.FileName)"
    }
})

# Apps events
$SearchAppsButton.Add_Click({
    try {
        if (-not $script:IsConnected) { Show-Info "Not connected" "Connect to Graph first."; return }
        $AppsStatusText.Text = "Searching apps..."
        $apps = Search-Apps $AppSearchBox.Text.Trim() ($AppPlatformBox.SelectedItem).Content
        Load-AppsGrid $apps
    } catch {
        $AppsStatusText.Text = "Search failed."
        Show-Error "Apps error" $_.Exception.Message
    }
})

$ListAllAppsButton.Add_Click({
    try {
        if (-not $script:IsConnected) { Show-Info "Not connected" "Connect to Graph first."; return }
        $AppsStatusText.Text = "Loading all apps..."
        $apps = Search-Apps "" ($AppPlatformBox.SelectedItem).Content
        Load-AppsGrid $apps
    } catch {
        $AppsStatusText.Text = "Load failed."
        Show-Error "Apps error" $_.Exception.Message
    }
})

$AppsGrid.Add_SelectionChanged({
    if ($AppsGrid.SelectedItem) {
        Update-AppDetails ($AppsGrid.SelectedItem -as [System.Data.DataRowView])
    }
})

$ExportAppsButton.Add_Click({
    if (-not $script:AppsTable -or $script:AppsTable.Rows.Count -eq 0) { $AppsStatusText.Text = "Nothing to export."; return }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "CSV files (*.csv)|*.csv"
    $dlg.FileName = "IntuneApps.csv"
    if ($dlg.ShowDialog()) {
        ($script:AppsTable | Select-Object DisplayName,AppType,IsAssigned,Id) |
            Export-Csv $dlg.FileName -NoTypeInformation -Encoding UTF8
        Show-Info "Export complete" "Exported to:`n$($dlg.FileName)"
    }
})

# Reports events
$RunReportButton.Add_Click({
    try {
        if (-not $script:IsConnected) { Show-Info "Not connected" "Connect to Graph first."; return }
        $type = ($ReportTypeBox.SelectedItem).Content
        $ReportsStatusText.Text = "Running report..."
        $dt = if ($type -eq "Device compliance report") { Run-DeviceComplianceReport } else { Run-AssignedAppsReport }

        $script:ReportsTable = $dt
        $ReportsGrid.ItemsSource = $dt.DefaultView
        $ReportsStatusText.Text = "Report complete. Rows: $($dt.Rows.Count)"
    }
    catch {
        $ReportsStatusText.Text = "Report failed."
        Show-Error "Reports error" $_.Exception.Message
    }
})

$ExportReportButton.Add_Click({
    if (-not $script:ReportsTable -or $script:ReportsTable.Rows.Count -eq 0) { $ReportsStatusText.Text = "Nothing to export."; return }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "CSV files (*.csv)|*.csv"
    $dlg.FileName = "IntuneReport.csv"
    if ($dlg.ShowDialog()) {
        $script:ReportsTable | Export-Csv $dlg.FileName -NoTypeInformation -Encoding UTF8
        Show-Info "Export complete" "Exported to:`n$($dlg.FileName)"
    }
})

# Settings events
$CheckModulesButton.Add_Click({ Check-Modules })
$InstallModulesButton.Add_Click({ Install-MissingModules })

$DisconnectButton.Add_Click({
    try {
        Disconnect-MgGraph | Out-Null
        $script:IsConnected = $false
        Set-ConnectionIndicator $false
        $OperationStatusText.Text = "Disconnected."
        $AssignmentsStatusText.Text = "Not connected."
        $AppsStatusText.Text = "Not connected."
        $ReportsStatusText.Text = "Not connected."
    } catch {}
    Update-SettingsContext
})

$ResetWorkspaceButton.Add_Click({
    $DeviceGrid.ItemsSource = $null
    $AssignmentsGrid.ItemsSource = $null
    $AppsGrid.ItemsSource = $null
    $ReportsGrid.ItemsSource = $null

    $OperationStatusText.Text = ""
    $AssignmentsStatusText.Text = ""
    $AppsStatusText.Text = ""
    $ReportsStatusText.Text = ""

    $AppDetailName.Text = ""
    $AppDetailPublisher.Text = ""
    $AppDetailType.Text = ""
    $AppDetailPlatforms.Text = ""
    $AppDetailAssignedCount.Text = ""
    $AppDetailLastModified.Text = ""
})

# Init
Set-ConnectionIndicator $false
Update-SettingsContext
Check-Modules

$window.ShowDialog() | Out-Null
