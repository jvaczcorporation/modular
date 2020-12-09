import 'package:flutter/material.dart';

import '../../flutter_modular.dart';

class ModularRouteInformationParser
    extends RouteInformationParser<ModularRoute> {
  @override
  Future<ModularRoute> parseRouteInformation(
      RouteInformation routeInformation) async {
    final path = routeInformation.location ?? '/';
    final route = await selectRoute(path);
    return route;
  }

  @override
  RouteInformation restoreRouteInformation(ModularRoute router) {
    return RouteInformation(location: router.path);
  }

  ModularRoute? _searchInModule(
      ChildModule module, String routerName, String path) {
    path = "/$path".replaceAll('//', '/');
    final routers =
        module.routers.map((e) => e.copyWith(currentModule: module)).toList();
    routers.sort((preview, actual) {
      return preview.routerName.contains('/:') ? 1 : 0;
    });
    for (var route in routers) {
      var r = _searchRoute(route, routerName, path);
      if (r != null) {
        return r;
      }
    }
    return null;
  }

  ModularRoute? _normalizeRoute(
      ModularRoute route, String routerName, String path) {
    ModularRoute? router;
    if (routerName == path || routerName == "$path/") {
      router = route.module!.routers[0];
      if (router.module != null) {
        var _routerName =
            (routerName + route.routerName).replaceFirst('//', '/');
        router = _searchInModule(route.module!, _routerName, path);
      }
    } else {
      router = _searchInModule(route.module!, routerName, path);
    }
    return router;
  }

  ModularRoute? _searchRoute(
      ModularRoute route, String routerName, String path) {
    final tempRouteName =
        (routerName + route.routerName).replaceFirst('//', '/');
    if (route.child == null) {
      var _routerName =
          ('$routerName${route.routerName}/').replaceFirst('//', '/');
      var router = _normalizeRoute(route, _routerName, path);

      if (router != null) {
        router = router.copyWith(
          modulePath: router.modulePath == null ? '/' : tempRouteName,
          path: path,
        );

        if (router.transition == TransitionType.defaultTransition) {
          router = router.copyWith(
            transition: route.transition,
            customTransition: route.customTransition,
          );
        }
        if (route.module != null) {
          Modular.bindModule(route.module!, path);
        }
        return router;
      }
    } else {
      if (tempRouteName.split('/').length != path.split('/').length) {
        return null;
      }
      var parseRoute = _parseUrlParams(route, tempRouteName, path);

      if (path != parseRoute.path) {
        return null;
      }

      if (parseRoute.currentModule != null) {
        Modular.bindModule(parseRoute.currentModule!, path);
        return route.copyWith(path: path);
      }
    }

    return null;
  }

  String prepareToRegex(String url) {
    final newUrl = <String>[];
    for (var part in url.split('/')) {
      var url = part.contains(":") ? "(.*?)" : part;
      newUrl.add(url);
    }

    return newUrl.join("/");
  }

  ModularRoute _parseUrlParams(
      ModularRoute router, String routeNamed, String path) {
    if (routeNamed.contains('/:')) {
      final regExp = RegExp(
        "^${prepareToRegex(routeNamed)}\$",
        caseSensitive: true,
      );
      var r = regExp.firstMatch(path);
      if (r != null) {
        var params = <String, String>{};
        var paramPos = 0;
        final routeParts = routeNamed.split('/');
        final pathParts = path.split('/');
        var newPath = router.path!;

        //  print('Match! Processing $path as $routeNamed');

        for (var routePart in routeParts) {
          if (routePart.contains(":")) {
            var paramName = routePart.replaceFirst(':', '');
            if (pathParts[paramPos].isNotEmpty) {
              newPath =
                  newPath.replaceFirst(':$paramName', pathParts[paramPos]);
              params[paramName] = pathParts[paramPos];
              routeNamed =
                  routeNamed.replaceFirst(routePart, params[paramName]!);
            }
          }
          paramPos++;
        }

        var _params = routeNamed != path ? null : params;
        return router.copyWith(
            args: router.args!.copyWith(params: _params), path: newPath);
      }

      return router.copyWith(args: router.args!.copyWith(params: null));
    }

    return router;
  }

  Future<ModularRoute> selectRoute(String path, [ChildModule? module]) async {
    if (path.isEmpty) {
      throw Exception("Router can not be empty");
    }
    var route = _searchInModule(module ?? Modular.initialModule, "", path);
    return canActivate(path, route);
  }

  Future<ModularRoute> canActivate(String path, ModularRoute? router) async {
    if (router == null) {
      throw ModularError('Route not found');
    }

    if (router.guards?.isNotEmpty == true) {
      for (var guard in router.guards!) {
        try {
          final result = await guard.canActivate(path, router);
          if (!result) {
            throw ModularError('$path is NOT ACTIVATE');
          }
          // ignore: avoid_catches_without_on_clauses
        } catch (e) {
          throw ModularError(
              'RouteGuard error. Check ($path) in ${router.currentModule.runtimeType}');
        }
      }
    }
    return router;
  }
}
