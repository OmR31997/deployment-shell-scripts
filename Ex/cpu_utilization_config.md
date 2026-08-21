======================================
       EC2 CPU ALARM SETUP
======================================

Instance ID: i-0123456789abcdef

Enter CPU utilization limit (%) [e.g. 80]: 80

When CPU reaches 80%, what should happen?

1) REBOOT EC2
2) STOP EC2
3) DO NOTHING

Select option [1-3]: 1

--------------------------------------
Instance : i-0123456789abcdef
CPU Limit: 80%
Action   : REBOOT
--------------------------------------

Continue? (y/n): y

Creating / updating CloudWatch alarm...

======================================
          SETUP COMPLETED
======================================

Instance : i-0123456789abcdef
CPU Limit: 80%
Action   : REBOOT
Alarm    : EC2-CPU-Utilization

✓ CloudWatch CPU alarm configured