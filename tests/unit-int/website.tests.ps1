. "${PSScriptRoot}\load.ps1"

InModuleScope sf-posh {

    Mock execute-native { }
    . "$PSScriptRoot\init.ps1"

    Describe "sf-iisSite-browse"  {
        It "do not open browser when no sitefinity selected" {
            Mock sf-project-getCurrent { $null }
            { sf-iisSite-browse } | Should -Throw "No project selected."
            Assert-MockCalled execute-native -Times 0 -Scope It
        }
    }
}
