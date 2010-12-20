package Statweb::Controller::Domainset;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Zonestat;

=head1 NAME

Statweb::Controller::Domainset - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Chained('/') : CaptureArgs(1) : PathPart('domainset') {
    my ($self, $c, $id) = @_;
    my $ds = $c->model('DB::Domainset')->find($id);

    $c->stash(
        {
            dset     => $ds,
            template => 'domainset/index.tt'
        }
    );
}

sub new_set :Local {
    my ($self, $c) = @_;
    my $name = $c->req->params->{name};
    
    my $dgroup = $c->model('DB::Dsgroup')->create({name => $name});
    my $dset = $dgroup->add_to_domainsets({});
    
    my $upload = $c->request->upload('userfile');
    
    if($upload) {
        my $fh = $upload->fh;
        my @res;
        while (my $line = <$fh>) {
            chomp($line);
            next if $line =~ /^\s*$/;
            push @res, $line;
        }

        $dset->dsgroup->new_content(@res);
    }
    
    $c->res->redirect(
        $c->uri_for_action('/domainset/first', [$dgroup->active_set->id]));
}

sub first : Chained('index') : Args(0) : PathPart('') {
    my ($self, $c) = @_;

    $c->detach('later', [1]);
}

sub later : Chained('index') : Args(1) : PathPart('') {
    my ($self, $c, $page) = @_;

    $c->stash->{rows} =
      $c->stash->{dset}
      ->search_related('glue', undef, { page => $page, rows => 25 });
    $c->stash->{page} = $c->stash->{rows}->pager;
}

sub delete : Chained('index') : Args(1) : PathPart('delete') {
    my ($self, $c, $domain_id) = @_;

    $c->stash->{dset}->remove_domain($domain_id);

    $c->res->redirect(
        $c->uri_for_action('/domainset/first', [$c->stash->{dset}->id]));
}

sub add : Chained('index') : Args(0) : PathPart('add') {
    my ($self, $c) = @_;
    my $domainname = $c->req->params->{domainname};
    my $domain = $c->model('DB::Domains')->find_or_create({ domain => $domainname });

    $c->stash->{dset}->add_to_glue({ domain_id => $domain->id });
    my $trs = $c->stash->{dset}->testruns;
    while (defined(my $tr = $trs->next)) {
        $tr->invalidate_cache;
    }

    $c->res->redirect(
        $c->uri_for_action('/domainset/first', [$c->stash->{dset}->id]));
}

sub rebuild : Chained('index') : Args(0) : PathPart('rebuild') {
    my ($self, $c) = @_;

    my $trs = $c->stash->{dset}->testruns;
    my $pr  = Zonestat->new->present;

    if (fork() == 0) {
        if (fork() == 0) {
            while (defined(my $tr = $trs->next)) {
                $tr->invalidate_cache;
                $pr->build_cache_for_testrun($tr);
            }
            exit(0);
        } else {
            exit(0);
        }
    }

    $c->res->redirect(
        $c->uri_for_action('/domainset/first', [$c->stash->{dset}->id]));
}

sub reload :Chained('index') :Args(0) :PathPart('reload') {
    my ($self, $c) = @_;
    my $upload = $c->request->upload('userfile')
        or die "No upload";
        
    my $fh = $upload->fh;
    my @res;
    while (my $line = <$fh>) {
        chomp($line);
        next if $line =~ /^\s*$/;
        push @res, $line;
    }
    
    $c->stash->{dset}->dsgroup->new_content(@res);
    $c->res->redirect(
        $c->uri_for_action('/domainset/first', [$c->stash->{dset}->dsgroup->active_set->id]));
}

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
