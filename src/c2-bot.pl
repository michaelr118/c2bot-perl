#!/usr/bin/perl
use DBI;
use POSIX qw(strftime);
use POSIX qw(tzset);
use Time::Local;

# 
$ENV{TZ} = "America/New_York";
tzset();

# Global var
$db_conn;
@sent_message;
@sent_L;
# End Global var
main();

sub main
{
	ConnectToDatabase();
	while (true)
	{
		my $n = (strftime("%H", localtime()) + 0);
        	$n = ($n >= 0 && $n < 7) ? ($n + 24) : $n;

		my $id = "S";
		if ($n >= 24)
		{
			my ($second, $minute, $hour, $day, $month, $year) = localtime();
			my $midday = timelocal(0, 0, 12, $day, $month, $year) - (24 * 60 * 60);
			($second, $minute, $hour, $day, $month, $year) = localtime($midday);
			$id .= strftime("%m%d%Y", $second, $minute, $hour, $day, $month, $year);
		}
		else
		{
			$id .= strftime("%m%d%Y", localtime());
		}
		
		my $query = $db_conn->prepare("DELETE FROM schedules WHERE ID<>'$id' OR ID IS NULL");
		my $r = $query->execute();
		$query->finish();

		$query = $db_conn->prepare("SELECT * FROM schedules WHERE ID='$id'");
		$r = $query->execute();

		while (my @row = $query->fetchrow_array())
		{
			my $user = $row[1];
			my $time_zone = $row[2];
			my $schedule = $row[3];

			#ProcessUser($user, $time_zone, $schedule);
			sleep(2);
		}
		$query->finish();
		sleep(5);
	}
	$db_conn->disconnect();
}

sub ConnectToDatabase
{
	$db_conn = DBI->connect("DBI:mysql:db_name:localhost",
		"username", "password");
}

# ProcessUser(string user, bit time_zone, string schedule)
sub ProcessUser
{
	my $user = $_[0];
	my $time_zone = $_[1];
	my $schedule = $_[2];

	my $jabber_user = "username";
	my $jabber_password = "password";
	my $jabber_domain = "example.com";
	my $user_domain = "example.com";

	my $hour = (strftime("%H", localtime()) + 0);
	$hour = ($hour >= 0 && $hour < 7) ? ($hour + 24) : $hour;
	$hour -= 7;

	my $minute = (strftime("%M", localtime()) + 0);
	my $index = ($hour * 2) + (($minute >= 25) ? 1 : 0);

	my $p = substr($schedule, $index, 1);
	my $prev_p = substr($schedule, ($index - 1), 1);

	if (($prev_p ne $p) && IndexNotSent($user, $index))
	{
		if ($p eq "." and $prev_p ne ".") { break; }
		my $ext = "posture";
		if ($p eq "P") { $ext = "posture1"; }
		elsif ($p eq "C") { $ext = "posture2"; }

		system("./jabber.py --jid $jabber_user\@$jabber_domain/$jabber_user -p " .
		"$jabber_password --to $user\@$user_domain --message " .
		"'Howdy, $user. I am a bot. Your posture is: $ext.' -q &> /dev/null");
	}

	my $L = index($schedule, "L");
        if (($index == ($L - 1)) && LNotSent($user, $L))
        {
                if ((($L % 2 == 0) && $minute >= 45) || (($L % 2 != 0) && $minute >= 15))
                {
                        system("./jabber.py --jid $jabber_user\@$jabber_domain/$jabber_user -p " .
                        "$jabber_password --to $user\@$user_domain --message " .
                        "'Hey. I am a bot. Your lunch is in 15 minutes. " .
                        "If you are in a live contact posture, you should message " .
                        "the floor lead now to let them know.' -q &> /dev/null");
                }
        }
}

# int IndexNotSent(string user, int index)
sub IndexNotSent
{
	my $user = $_[0];
	my $index = $_[1];

	for my $i (0 .. $#sent_message)
	{
		if ($sent_message[$i][0] eq $user
			&& $sent_message[$i][1] == $index)
		{
			return 0;
		}
		elsif ($sent_message[$i][0] eq $user)
		{
			$sent_message[$i][1] = $index;
			return 1;
		}
	}

	push(@sent_message, [$user, $index]);
	return 1;
}

# int LNotSent(string user, int index)
sub LNotSent
{
        my $user = $_[0];
        my $index = $_[1];

        for my $i (0 .. $#sent_L)
        {
                if ($sent_L[$i][0] eq $user
                        && $sent_L[$i][1] == $index)
                {
                        return 0;
                }
                elsif ($sent_L[$i][0] eq $user)
                {
                        $sent_L[$i][1] = $index;
                        return 1;
                }
        }

        push(@sent_L, [$user, $index]);
        return 1;
}
