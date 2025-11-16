/**
 * @description Test class for SER_ServiceDashboardController
 * @author Tribal AI
 * @date 2024
 */
@IsTest
private class SER_ServiceDashboardControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test accounts with health scores
        List<Account> accounts = new List<Account>();
        
        // Red accounts (health score < 50)
        for (Integer i = 1; i <= 3; i++) {
            Account acc = new Account();
            acc.Name = 'Red Account ' + i;
            acc.SER_HealthScore__c = 30 + i; // 31, 32, 33
            accounts.add(acc);
        }
        
        // Healthy accounts (health score >= 50)
        for (Integer i = 1; i <= 2; i++) {
            Account acc = new Account();
            acc.Name = 'Healthy Account ' + i;
            acc.SER_HealthScore__c = 70 + i; // 71, 72
            accounts.add(acc);
        }
        
        insert accounts;
        
        // Create test cases
        List<Case> cases = new List<Case>();
        
        // Create P1 cases for red accounts
        for (Integer i = 0; i < 3; i++) {
            Case c = new Case();
            c.Subject = 'P1 Case ' + (i + 1);
            c.Priority = 'P1';
            c.Status = 'New';
            c.AccountId = accounts[i].Id;
            c.Origin = 'Web';
            cases.add(c);
        }
        
        // Create P2 cases for red accounts
        for (Integer i = 0; i < 3; i++) {
            Case c = new Case();
            c.Subject = 'P2 Case ' + (i + 1);
            c.Priority = 'P2';
            c.Status = 'Working';
            c.AccountId = accounts[i].Id;
            c.Origin = 'Email';
            cases.add(c);
        }
        
        // Create P3 cases (not urgent)
        for (Integer i = 0; i < 2; i++) {
            Case c = new Case();
            c.Subject = 'P3 Case ' + (i + 1);
            c.Priority = 'P3';
            c.Status = 'New';
            c.AccountId = accounts[i + 3].Id;
            c.Origin = 'Phone';
            cases.add(c);
        }
        
        // Create some closed P1/P2 cases for resolution time calculation
        for (Integer i = 0; i < 2; i++) {
            Case c = new Case();
            c.Subject = 'Closed P1 Case ' + (i + 1);
            c.Priority = 'P1';
            c.Status = 'Closed';
            c.AccountId = accounts[i].Id;
            c.Origin = 'Web';
            cases.add(c);
        }
        
        insert cases;
        
        // Close the last 2 cases
        List<Case> casesToClose = [SELECT Id FROM Case WHERE Subject LIKE 'Closed P1 Case%'];
        for (Case c : casesToClose) {
            c.Status = 'Closed';
        }
        update casesToClose;
    }
    
    @IsTest
    static void testGetDashboardDataThisWeek() {
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('thisWeek');
        Test.stopTest();
        
        // Verify urgent cases (P1 and P2)
        System.assertNotEquals(null, result, 'Dashboard data should not be null');
        System.assertNotEquals(null, result.urgentCases, 'Urgent cases should not be null');
        System.assertEquals(6, result.urgentCases.size(), 'Should have 6 urgent cases (3 P1 + 3 P2)');
        
        // Verify red accounts
        System.assertNotEquals(null, result.redAccounts, 'Red accounts should not be null');
        System.assertEquals(3, result.redAccounts.size(), 'Should have 3 red accounts');
        
        // Verify metrics
        System.assertNotEquals(null, result.metrics, 'Metrics should not be null');
        System.assertEquals(6, result.metrics.totalUrgentCases, 'Total urgent cases should be 6');
        System.assertEquals(3, result.metrics.totalRedAccounts, 'Total red accounts should be 3');
        System.assertEquals(3, result.metrics.p1Cases, 'P1 cases should be 3');
        System.assertEquals(3, result.metrics.p2Cases, 'P2 cases should be 3');
        
        // Verify trends
        System.assertNotEquals(null, result.trends, 'Trends should not be null');
    }
    
    @IsTest
    static void testGetDashboardDataThisMonth() {
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('thisMonth');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Dashboard data should not be null');
        System.assertEquals(6, result.urgentCases.size(), 'Should have 6 urgent cases');
        System.assertEquals(3, result.redAccounts.size(), 'Should have 3 red accounts');
    }
    
    @IsTest
    static void testGetDashboardDataThisQuarter() {
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('thisQuarter');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Dashboard data should not be null');
        System.assertEquals(6, result.urgentCases.size(), 'Should have 6 urgent cases');
        System.assertEquals(3, result.redAccounts.size(), 'Should have 3 red accounts');
    }
    
    @IsTest
    static void testGetDashboardDataInvalidTimeFrame() {
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('invalid');
        Test.stopTest();
        
        // Should default to this week
        System.assertNotEquals(null, result, 'Dashboard data should not be null');
        System.assertEquals(6, result.urgentCases.size(), 'Should have 6 urgent cases');
    }
    
    @IsTest
    static void testUrgentCaseDataStructure() {
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('thisWeek');
        Test.stopTest();
        
        System.assert(result.urgentCases.size() > 0, 'Should have urgent cases');
        
        SER_ServiceDashboardController.UrgentCase firstCase = result.urgentCases[0];
        System.assertNotEquals(null, firstCase.id, 'Case ID should not be null');
        System.assertNotEquals(null, firstCase.caseNumber, 'Case number should not be null');
        System.assertNotEquals(null, firstCase.subject, 'Case subject should not be null');
        System.assertNotEquals(null, firstCase.status, 'Case status should not be null');
        System.assertNotEquals(null, firstCase.priority, 'Case priority should not be null');
        System.assert(firstCase.priority == 'P1' || firstCase.priority == 'P2', 'Priority should be P1 or P2');
        System.assert(firstCase.ageInDays >= 0, 'Age in days should be non-negative');
    }
    
    @IsTest
    static void testRedAccountDataStructure() {
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('thisWeek');
        Test.stopTest();
        
        System.assert(result.redAccounts.size() > 0, 'Should have red accounts');
        
        SER_ServiceDashboardController.RedAccount firstAccount = result.redAccounts[0];
        System.assertNotEquals(null, firstAccount.id, 'Account ID should not be null');
        System.assertNotEquals(null, firstAccount.name, 'Account name should not be null');
        System.assertNotEquals(null, firstAccount.healthScore, 'Health score should not be null');
        System.assert(firstAccount.healthScore < 50, 'Health score should be less than 50');
        System.assert(firstAccount.totalOpenCases >= 0, 'Total open cases should be non-negative');
        System.assert(firstAccount.urgentCases >= 0, 'Urgent cases should be non-negative');
        System.assert(firstAccount.averageCaseAge >= 0, 'Average case age should be non-negative');
        System.assertNotEquals(null, firstAccount.topCases, 'Top cases should not be null');
    }
    
    @IsTest
    static void testMetricsCalculation() {
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('thisWeek');
        Test.stopTest();
        
        SER_ServiceDashboardController.DashboardMetrics metrics = result.metrics;
        
        // Test case counts
        System.assertEquals(6, metrics.totalUrgentCases, 'Total urgent cases should be 6');
        System.assertEquals(3, metrics.p1Cases, 'P1 cases should be 3');
        System.assertEquals(3, metrics.p2Cases, 'P2 cases should be 3');
        System.assertEquals(3, metrics.totalRedAccounts, 'Total red accounts should be 3');
        
        // Test maps are initialized
        System.assertNotEquals(null, metrics.casesByOwner, 'Cases by owner map should not be null');
        System.assertNotEquals(null, metrics.casesByCustomer, 'Cases by customer map should not be null');
        
        // Test average resolution time is calculated
        System.assert(metrics.averageResolutionTime >= 0, 'Average resolution time should be non-negative');
    }
    
    @IsTest
    static void testTrendDataGeneration() {
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('thisWeek');
        Test.stopTest();
        
        System.assertNotEquals(null, result.trends, 'Trends should not be null');
        
        // If there are trends, verify structure
        if (result.trends.size() > 0) {
            SER_ServiceDashboardController.TrendData firstTrend = result.trends[0];
            System.assertNotEquals(null, firstTrend.period, 'Period should not be null');
            System.assertNotEquals(null, firstTrend.periodDate, 'Period date should not be null');
            System.assert(firstTrend.caseCount >= 0, 'Case count should be non-negative');
        }
    }
    
    @IsTest
    static void testExceptionHandling() {
        // Test with null parameter
        Test.startTest();
        try {
            SER_ServiceDashboardController.DashboardData result = 
                SER_ServiceDashboardController.getDashboardData(null);
            // Should not throw exception, should default to thisWeek
            System.assertNotEquals(null, result, 'Should handle null parameter gracefully');
        } catch (Exception e) {
            System.assert(false, 'Should not throw exception for null parameter: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testEmptyDataScenario() {
        // Delete all test data to test empty scenario
        delete [SELECT Id FROM Case];
        delete [SELECT Id FROM Account];
        
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('thisWeek');
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Dashboard data should not be null');
        System.assertEquals(0, result.urgentCases.size(), 'Should have no urgent cases');
        System.assertEquals(0, result.redAccounts.size(), 'Should have no red accounts');
        System.assertEquals(0, result.metrics.totalUrgentCases, 'Total urgent cases should be 0');
        System.assertEquals(0, result.metrics.totalRedAccounts, 'Total red accounts should be 0');
    }
    
    @IsTest
    static void testRedAccountTopCases() {
        Test.startTest();
        SER_ServiceDashboardController.DashboardData result = 
            SER_ServiceDashboardController.getDashboardData('thisWeek');
        Test.stopTest();
        
        // Find a red account with cases
        SER_ServiceDashboardController.RedAccount accountWithCases = null;
        for (SER_ServiceDashboardController.RedAccount ra : result.redAccounts) {
            if (ra.topCases.size() > 0) {
                accountWithCases = ra;
                break;
            }
        }
        
        System.assertNotEquals(null, accountWithCases, 'Should have at least one red account with cases');
        System.assert(accountWithCases.topCases.size() > 0, 'Red account should have top cases');
        System.assert(accountWithCases.totalOpenCases > 0, 'Red account should have open cases count');
    }
}