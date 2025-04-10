#!/usr/bin/env python3

from __future__ import annotations

import typing
import argparse
import sys
from pathlib import Path
from ipaddress import IPv4Network, IPv6Network, AddressValueError

try:
    from aggregate_prefixes import aggregate_prefixes
except ImportError:
    aggregate_prefixes = None


def prepare_networks(
    nets_or_files: typing.List[str], family: typing.List[int]
) -> typing.List[IPv4Network | IPv6Network]:
    networks = []
    for net in nets_or_files:
        if not family or 4 in family:
            try:
                networks.append(IPv4Network(net))
            except AddressValueError:
                pass
        if not family or 6 in family:
            try:
                networks.append(IPv6Network(net))
            except AddressValueError:
                pass
    for file in nets_or_files:
        file_path = Path(file).resolve()
        if not file_path.exists() or not file_path.is_file():
            continue
        with file_path.open(encoding='utf-8') as fp:
            for line in fp:
                if not family or 4 in family:
                    try:
                        networks.append(IPv4Network(line.strip()))
                    except AddressValueError:
                        pass
                if not family or 6 in family:
                    try:
                        networks.append(IPv6Network(line.strip()))
                    except AddressValueError:
                        pass
    return networks


def find_updated_networks(
    networks: typing.List[IPv4Network | IPv6Network], subnet: IPv4Network | IPv6Network
) -> typing.List[IPv4Network | IPv6Network]:
    copied_networks = networks.copy()
    for index, network in enumerate(networks):
        if type(network) is not type(subnet):
            continue
        if subnet.subnet_of(network):  # type: ignore
            copied_networks.pop(index)
            copied_networks.extend(list(network.address_exclude(subnet)))  # type: ignore
    return copied_networks


def run(args: argparse.Namespace) -> None:
    includes = getattr(args, 'include', [])
    excludes = getattr(args, 'exclude', [])
    family = getattr(args, 'family', [])
    output: Path | None = getattr(args, 'output', None)

    in_networks = prepare_networks(includes, family)
    if len(in_networks) == 0:
        print('No legal include ip networks.')
        sys.exit(1)
    ex_networks = prepare_networks(excludes, family)
    out_networks = in_networks.copy()
    for exclude in ex_networks:
        out_networks = find_updated_networks(out_networks, exclude)
    if aggregate_prefixes is not None:
        out4 = []
        out6 = []
        for net in out_networks:
            if (not family or 4 in family) and isinstance(net, IPv4Network):
                out4.append(net)
            if (not family or 6 in family) and isinstance(net, IPv6Network):
                out6.append(net)
        out4 = aggregate_prefixes(out4)
        out6 = aggregate_prefixes(out6)
        out_networks = []
        out_networks.extend(out4)
        out_networks.extend(out6)

    output_lines = [
        f'{getattr(args, "prefix", "")}{str(network)}{getattr(args, "suffix", "")}\n'
        for network in out_networks
    ]

    if output is None:
        for line in output_lines:
            print(line, end='')
    else:
        print(f'Included Networks: {len(in_networks)}')
        output_file = output.resolve()
        if output_file.is_dir():
            print('Can not write to directory.')
            sys.exit(1)
        if not output_file.parent.exists():
            output_file.parent.mkdir(parents=True)
        if output_file.exists():
            with output_file.open('a', encoding='utf-8') as wfp:
                wfp.writelines(output_lines)
        else:
            with output_file.open('w', encoding='utf-8') as wfp:
                wfp.writelines(output_lines)
        print(f'Generated Networks: {len(output_lines)}')


def main() -> None:
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        'include',
        nargs='+',
        type=str,
        default=[],
        help='include networks (subnets or files separated by space)',
    )
    parser.add_argument(
        '-e',
        '--exclude',
        nargs='+',
        type=str,
        default=[],
        help='exclude networks (subnets or files separated by space)',
    )
    parser.add_argument(
        '-4',
        dest='family',
        action='append_const',
        const=4,
        help='process ipv4 only',
    )
    parser.add_argument(
        '-6',
        dest='family',
        action='append_const',
        const=6,
        help='process ipv6 only',
    )
    parser.add_argument('-o', '--output', type=Path, help='output file to write')
    parser.add_argument(
        '-p', '--prefix', type=str, default='', help='write line prefix'
    )
    parser.add_argument(
        '-s', '--suffix', type=str, default='', help='write line suffix'
    )
    parser.set_defaults(func=run)
    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
