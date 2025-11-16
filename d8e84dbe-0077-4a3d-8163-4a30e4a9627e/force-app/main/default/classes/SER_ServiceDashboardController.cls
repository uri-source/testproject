/**
 * @description Controller for Service Dashboard LWC providing data for urgent cases,
 * red accounts, and service analytics with time frame filtering
 * @author Tribal AI
 * @date 2024
 */
public with sharing class SER_ServiceDashboardController {
    
    /**
     * @description Wrapper class for dashboard data
     */
    public class DashboardData {
        @AuraEnabled public List<UrgentCase> urgentCases { get; set; }
        @AuraEnabled public List<RedAccount> redAccounts { get; set; }
        @AuraEnabled public DashboardMetrics metrics { get; set; }
        @AuraEnabled public List<TrendData> trends { get; set; }
        
        public DashboardData() {
            this.urgentCases = new List<UrgentCase>();
            this.redAccounts = new List<RedAccount>();
            this.metrics = new DashboardMetrics();
            this.trends = new List<TrendData>();
        }
    }
    
    /**
     * @description Wrapper class for urgent case data
     */
    public class UrgentCase {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String priority { get; set; }
        @AuraEnabled public String severity { get; set; }
        @AuraEnabled public Integer ageInDays { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public String accountName { get; set; }
        @AuraEnabled public DateTime createdDate { get; set; }
    }
    
    /**
     * @description Wrapper class for red account data
     */
    public class RedAccount {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Decimal healthScore { get; set; }
        @AuraEnabled public Integer totalOpenCases { get; set; }
        @AuraEnabled public Integer urgentCases { get; set; }
        @AuraEnabled public Double averageCaseAge { get; set; }
        @AuraEnabled public String ownerName { get; set; }
        @AuraEnabled public List<UrgentCase> topCases { get; set; }
        
        public RedAccount() {
            this.topCases = new List<UrgentCase>();
        }
    }
    
    /**
     * @description Wrapper class for dashboard metrics
     */
    public class DashboardMetrics {
        @AuraEnabled public Integer totalUrgentCases { get; set; }
        @AuraEnabled public Integer totalRedAccounts { get; set; }
        @AuraEnabled public Integer p1Cases { get; set; }
        @AuraEnabled public Integer p2Cases { get; set; }
        @AuraEnabled public Double averageResolutionTime { get; set; }
        @AuraEnabled public Map<String, Integer> casesByOwner { get; set; }
        @AuraEnabled public Map<String, Integer> casesByCustomer { get; set; }
        
        public DashboardMetrics() {
            this.totalUrgentCases = 0;
            this.totalRedAccounts = 0;
            this.p1Cases = 0;
            this.p2Cases = 0;
            this.averageResolutionTime = 0.0;
            this.casesByOwner = new Map<String, Integer>();
            this.casesByCustomer = new Map<String, Integer>();
        }
    }
    
    /**
     * @description Wrapper class for trend data
     */
    public class TrendData {
        @AuraEnabled public String period { get; set; }
        @AuraEnabled public Integer caseCount { get; set; }
        @AuraEnabled public Date periodDate { get; set; }
    }
    
    /**
     * @description Get complete dashboard data for the specified time frame
     * @param timeFrame The time frame filter: 'thisWeek', 'thisMonth', or 'thisQuarter'
     * @return DashboardData Complete dashboard data including cases, accounts, metrics, and trends
     */
    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboardData(String timeFrame) {
        try {
            DashboardData data = new DashboardData();
            
            // Get date range based on time frame
            DateRange dateRange = getDateRange(timeFrame);
            
            // Get urgent cases
            data.urgentCases = getUrgentCases(dateRange);
            
            // Get red accounts with their top cases
            data.redAccounts = getRedAccounts(dateRange);
            
            // Calculate metrics
            data.metrics = calculateMetrics(data.urgentCases, data.redAccounts, dateRange);
            
            // Get trend data
            data.trends = getTrendData(timeFrame, dateRange);
            
            return data;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving dashboard data: ' + e.getMessage());
        }
    }
    
    /**
     * @description Get urgent cases (P1 and P2 severity) for the specified date range
     * @param dateRange The date range to filter cases
     * @return List<UrgentCase> List of urgent cases
     */
    private static List<UrgentCase> getUrgentCases(DateRange dateRange) {
        List<UrgentCase> urgentCases = new List<UrgentCase>();
        
        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Status, Priority, 
                   Owner.Name, Account.Name, CreatedDate,
                   (SELECT Id FROM Cases WHERE Priority IN ('P1', 'P2') AND CreatedDate >= :dateRange.startDate AND CreatedDate <= :dateRange.endDate LIMIT 1)
            FROM Case 
            WHERE Priority IN ('P1', 'P2') 
            AND CreatedDate >= :dateRange.startDate 
            AND CreatedDate <= :dateRange.endDate
            ORDER BY Priority ASC, CreatedDate DESC
            LIMIT 100
        ];
        
        for (Case c : cases) {
            UrgentCase uc = new UrgentCase();
            uc.id = c.Id;
            uc.caseNumber = c.CaseNumber;
            uc.subject = c.Subject;
            uc.status = c.Status;
            uc.priority = c.Priority;
            uc.severity = c.Priority; // Using Priority as severity for this implementation
            uc.ownerName = c.Owner.Name;
            uc.accountName = c.Account?.Name;
            uc.createdDate = c.CreatedDate;
            uc.ageInDays = c.CreatedDate != null ? Date.today().daysBetween(c.CreatedDate.date()) : 0;
            
            urgentCases.add(uc);
        }
        
        return urgentCases;
    }
    
    /**
     * @description Get red accounts (health score < 50) with their top cases
     * @param dateRange The date range to filter cases
     * @return List<RedAccount> List of red accounts with their top cases
     */
    private static List<RedAccount> getRedAccounts(DateRange dateRange) {
        List<RedAccount> redAccounts = new List<RedAccount>();
        
        List<Account> accounts = [
            SELECT Id, Name, SER_HealthScore__c, Owner.Name,
                   (SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate, Owner.Name
                    FROM Cases 
                    WHERE IsClosed = false 
                    AND CreatedDate >= :dateRange.startDate 
                    AND CreatedDate <= :dateRange.endDate
                    ORDER BY Priority ASC, CreatedDate DESC 
                    LIMIT 5)
            FROM Account 
            WHERE SER_HealthScore__c < 50 
            AND SER_HealthScore__c != null
            ORDER BY SER_HealthScore__c ASC
            LIMIT 50
        ];
        
        for (Account acc : accounts) {
            RedAccount ra = new RedAccount();
            ra.id = acc.Id;
            ra.name = acc.Name;
            ra.healthScore = acc.SER_HealthScore__c;
            ra.ownerName = acc.Owner.Name;
            
            // Calculate metrics for this account
            ra.totalOpenCases = acc.Cases.size();
            ra.urgentCases = 0;
            Integer totalAge = 0;
            
            // Convert cases to UrgentCase format and calculate metrics
            for (Case c : acc.Cases) {
                UrgentCase uc = new UrgentCase();
                uc.id = c.Id;
                uc.caseNumber = c.CaseNumber;
                uc.subject = c.Subject;
                uc.status = c.Status;
                uc.priority = c.Priority;
                uc.severity = c.Priority;
                uc.ownerName = c.Owner.Name;
                uc.createdDate = c.CreatedDate;
                uc.ageInDays = c.CreatedDate != null ? Date.today().daysBetween(c.CreatedDate.date()) : 0;
                
                ra.topCases.add(uc);
                
                if (c.Priority == 'P1' || c.Priority == 'P2') {
                    ra.urgentCases++;
                }
                totalAge += uc.ageInDays;
            }
            
            ra.averageCaseAge = ra.totalOpenCases > 0 ? (Double)totalAge / ra.totalOpenCases : 0.0;
            
            redAccounts.add(ra);
        }
        
        return redAccounts;
    }
    
    /**
     * @description Calculate dashboard metrics
     * @param urgentCases List of urgent cases
     * @param redAccounts List of red accounts
     * @param dateRange The date range for calculations
     * @return DashboardMetrics Calculated metrics
     */
    private static DashboardMetrics calculateMetrics(List<UrgentCase> urgentCases, List<RedAccount> redAccounts, DateRange dateRange) {
        DashboardMetrics metrics = new DashboardMetrics();
        
        metrics.totalUrgentCases = urgentCases.size();
        metrics.totalRedAccounts = redAccounts.size();
        
        // Count P1 and P2 cases
        for (UrgentCase uc : urgentCases) {
            if (uc.priority == 'P1') {
                metrics.p1Cases++;
            } else if (uc.priority == 'P2') {
                metrics.p2Cases++;
            }
        }
        
        // Calculate cases by owner
        for (UrgentCase uc : urgentCases) {
            String owner = uc.ownerName != null ? uc.ownerName : 'Unassigned';
            Integer count = metrics.casesByOwner.get(owner);
            metrics.casesByOwner.put(owner, count != null ? count + 1 : 1);
        }
        
        // Calculate cases by customer
        for (UrgentCase uc : urgentCases) {
            String customer = uc.accountName != null ? uc.accountName : 'Unknown';
            Integer count = metrics.casesByCustomer.get(customer);
            metrics.casesByCustomer.put(customer, count != null ? count + 1 : 1);
        }
        
        // Calculate average resolution time for closed cases in the period
        List<Case> closedCases = [
            SELECT Id, CreatedDate, ClosedDate
            FROM Case 
            WHERE IsClosed = true 
            AND Priority IN ('P1', 'P2')
            AND ClosedDate >= :dateRange.startDate 
            AND ClosedDate <= :dateRange.endDate
            LIMIT 1000
        ];
        
        if (!closedCases.isEmpty()) {
            Long totalResolutionTime = 0;
            for (Case c : closedCases) {
                if (c.CreatedDate != null && c.ClosedDate != null) {
                    totalResolutionTime += c.ClosedDate.getTime() - c.CreatedDate.getTime();
                }
            }
            metrics.averageResolutionTime = totalResolutionTime > 0 ? 
                (Double)(totalResolutionTime / (1000 * 60 * 60 * 24)) / closedCases.size() : 0.0; // Convert to days
        }
        
        return metrics;
    }
    
    /**
     * @description Get trend data for case volume over time
     * @param timeFrame The time frame for trends
     * @param dateRange The date range for data
     * @return List<TrendData> Trend data points
     */
    private static List<TrendData> getTrendData(String timeFrame, DateRange dateRange) {
        List<TrendData> trends = new List<TrendData>();
        
        // Get case counts grouped by date
        List<AggregateResult> results = [
            SELECT DAY_ONLY(CreatedDate) day, COUNT(Id) caseCount
            FROM Case 
            WHERE Priority IN ('P1', 'P2')
            AND CreatedDate >= :dateRange.startDate 
            AND CreatedDate <= :dateRange.endDate
            GROUP BY DAY_ONLY(CreatedDate)
            ORDER BY DAY_ONLY(CreatedDate)
        ];
        
        for (AggregateResult ar : results) {
            TrendData td = new TrendData();
            td.periodDate = (Date)ar.get('day');
            td.caseCount = (Integer)ar.get('caseCount');
            td.period = td.periodDate.format();
            trends.add(td);
        }
        
        return trends;
    }
    
    /**
     * @description Get date range based on time frame
     * @param timeFrame The time frame string
     * @return DateRange The calculated date range
     */
    private static DateRange getDateRange(String timeFrame) {
        DateRange range = new DateRange();
        Date today = Date.today();
        
        if (timeFrame == 'thisWeek') {
            range.startDate = today.toStartOfWeek();
            range.endDate = range.startDate.addDays(6);
        } else if (timeFrame == 'thisMonth') {
            range.startDate = today.toStartOfMonth();
            range.endDate = range.startDate.addMonths(1).addDays(-1);
        } else if (timeFrame == 'thisQuarter') {
            Integer currentMonth = today.month();
            Integer quarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1;
            range.startDate = Date.newInstance(today.year(), quarterStartMonth, 1);
            range.endDate = range.startDate.addMonths(3).addDays(-1);
        } else {
            // Default to this week
            range.startDate = today.toStartOfWeek();
            range.endDate = range.startDate.addDays(6);
        }
        
        return range;
    }
    
    /**
     * @description Helper class for date ranges
     */
    private class DateRange {
        public Date startDate { get; set; }
        public Date endDate { get; set; }
    }
}